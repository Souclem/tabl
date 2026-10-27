-- ============================================================
--  « Demander un avis » à un proche qui est allé dans un restaurant
-- ============================================================
--  Décision du 2026-10-27 : une demande privée, à laquelle le proche
--  répond en un toucher (😍 Oui, vas-y / 🤔 Ça dépend / 😕 Je ne
--  conseille pas), un mot en plus s'il veut. Rien n'est publié : seuls
--  celui qui demande et celui à qui on demande voient la demande et sa
--  réponse. On ne demande qu'à quelqu'un qu'on suit.
--
--  La demande et la réponse arrivent par les notifications :
--  `mes_notifications()` est recréée avec deux types de plus
--  ('demande_avis', 'avis_recu') et trois colonnes (le restaurant
--  directement, la réponse, l'identifiant de la demande).
-- ============================================================

create table public.demandes_avis (
  id uuid primary key default gen_random_uuid(),
  demandeur_id uuid not null references public.profils (id) on delete cascade,
  destinataire_id uuid not null references public.profils (id) on delete cascade,
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  message text not null check (char_length(message) between 1 and 300),
  reponse text check (reponse in ('oui', 'depend', 'non')),
  mot text check (char_length(mot) <= 200),
  cree_le timestamptz not null default now(),
  repondu_le timestamptz,
  constraint pas_a_soi_meme check (demandeur_id <> destinataire_id)
);

create index demandes_avis_destinataire
  on public.demandes_avis (destinataire_id, cree_le desc);
create index demandes_avis_demandeur
  on public.demandes_avis (demandeur_id, cree_le desc);

grant select, insert, delete on public.demandes_avis to authenticated;
-- Répondre ne touche qu'à la réponse : ni le message ni le restaurant.
grant update (reponse, mot, repondu_le) on public.demandes_avis to authenticated;

alter table public.demandes_avis enable row level security;

create policy "lire ses demandes d'avis"
  on public.demandes_avis for select
  to authenticated
  using (auth.uid() = demandeur_id or auth.uid() = destinataire_id);

-- Demander : en son nom, à quelqu'un qu'on suit (suivi accepté).
create policy "demander un avis"
  on public.demandes_avis for insert
  to authenticated
  with check (
    auth.uid() = demandeur_id
    and reponse is null
    and exists (
      select 1 from public.abonnements a
      where a.suiveur_id = auth.uid()
        and a.suivi_id = destinataire_id
        and a.statut = 'accepte'
    )
  );

-- Répondre : seulement celui à qui on a demandé.
create policy "repondre a une demande d'avis"
  on public.demandes_avis for update
  to authenticated
  using (auth.uid() = destinataire_id)
  with check (auth.uid() = destinataire_id);

-- Retirer sa demande.
create policy "retirer sa demande d'avis"
  on public.demandes_avis for delete
  to authenticated
  using (auth.uid() = demandeur_id);

-- ------------------------------------------------------------
--  Les notifications, avec les demandes et les réponses. Même corps
--  que `20261027010000_notifications.sql`, plus deux sources et trois
--  colonnes.
-- ------------------------------------------------------------
drop function if exists public.mes_notifications(integer);

create function public.mes_notifications(p_limite integer default 80)
returns table (
  type text,
  acteur_id uuid,
  acteur_pseudo text,
  acteur_photo text,
  souvenir_id uuid,
  souvenir_photo text,
  restaurant_id uuid,
  restaurant_nom text,
  texte text,
  reponse text,
  demande_id uuid,
  cree_le timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  with moi as (select auth.uid() as id),
  evenements as (
    select 'demande_suivi' as type, a.suiveur_id as acteur_id,
           null::uuid as souvenir_id, null::uuid as restaurant_id,
           null::text as texte, null::text as reponse,
           null::uuid as demande_id, a.cree_le
    from public.abonnements a, moi
    where a.suivi_id = moi.id and a.statut = 'en_attente'
    union all
    select 'nouvel_abonne', a.suiveur_id, null, null, null, null, null,
           coalesce(a.accepte_le, a.cree_le)
    from public.abonnements a, moi
    where a.suivi_id = moi.id and a.statut = 'accepte'
    union all
    select 'suivi_accepte', a.suivi_id, null, null, null, null, null,
           a.accepte_le
    from public.abonnements a, moi
    where a.suiveur_id = moi.id
      and a.statut = 'accepte'
      and a.accepte_le is not null
      and a.accepte_le > a.cree_le + interval '2 seconds'
    union all
    select 'reaction', r.profil_id, r.souvenir_id, null, null, null, null,
           r.cree_le
    from public.reactions r
    join public.souvenirs s on s.id = r.souvenir_id, moi
    where s.auteur_id = moi.id and r.profil_id <> moi.id
    union all
    select 'commentaire', c.auteur_id, c.souvenir_id, null, c.texte, null,
           null, c.cree_le
    from public.commentaires c
    join public.souvenirs s on s.id = c.souvenir_id, moi
    where s.auteur_id = moi.id and c.auteur_id <> moi.id
    union all
    -- On me demande mon avis, et je n'ai pas encore répondu.
    select 'demande_avis', d.demandeur_id, null, d.restaurant_id,
           d.message, null, d.id, d.cree_le
    from public.demandes_avis d, moi
    where d.destinataire_id = moi.id and d.reponse is null
    union all
    -- On a répondu à ma demande.
    select 'avis_recu', d.destinataire_id, null, d.restaurant_id,
           d.mot, d.reponse, d.id, d.repondu_le
    from public.demandes_avis d, moi
    where d.demandeur_id = moi.id
      and d.reponse is not null
      and d.repondu_le is not null
  )
  select e.type, e.acteur_id, p.pseudo, p.photo_url,
         e.souvenir_id, s.photo_url,
         coalesce(e.restaurant_id, s.restaurant_id), r.nom,
         e.texte, e.reponse, e.demande_id, e.cree_le
  from evenements e
  join public.profils p on p.id = e.acteur_id
  left join public.souvenirs s on s.id = e.souvenir_id
  left join public.restaurants r on r.id = coalesce(e.restaurant_id, s.restaurant_id)
  order by e.cree_le desc
  limit least(greatest(p_limite, 1), 200);
$$;

revoke execute on function public.mes_notifications(integer) from public, anon;
grant execute on function public.mes_notifications(integer) to authenticated;
