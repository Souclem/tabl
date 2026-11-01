-- ============================================================
--  Commentaires : répondre, et aimer un commentaire
-- ============================================================
--  Demandé le 2026-11-01 : « un commentaire peut être liké et on peut y
--  répondre (profondeur max 1) », comme sur Instagram.
--
--  - `commentaires.parent_id` : le commentaire auquel celui-ci répond.
--    Un seul niveau : on répond à un commentaire, jamais à une réponse
--    (l'app rattache une réponse à une réponse au même fil). La policy
--    d'insertion le garantit.
--  - `commentaires_reactions` : les j'aime d'un commentaire, un par
--    personne, comme `reactions` pour un moment.
--  - `mes_notifications()` : deux sources de plus (une réponse à mon
--    commentaire, un j'aime sur mon commentaire) et l'identifiant du
--    commentaire, pour rassembler les j'aime d'un même commentaire.
--  - Les droits de la fonction `notifier`, qui prévient aussi de ces
--    deux-là sur le téléphone.
-- ============================================================

alter table public.commentaires
  add column parent_id uuid references public.commentaires (id) on delete cascade;

create index commentaires_parent on public.commentaires (parent_id)
  where parent_id is not null;

drop policy "commenter un souvenir visible" on public.commentaires;

create policy "commenter un souvenir visible"
  on public.commentaires for insert
  to authenticated
  with check (
    auteur_id = auth.uid()
    and exists (
      select 1 from public.souvenirs s
      where s.id = commentaires.souvenir_id
    )
    -- Une réponse répond à un commentaire du même moment, qui n'est pas
    -- lui-même une réponse.
    and (
      commentaires.parent_id is null
      or exists (
        select 1 from public.commentaires p
        where p.id = commentaires.parent_id
          and p.souvenir_id = commentaires.souvenir_id
          and p.parent_id is null
      )
    )
  );

-- Une clé à elle, plutôt que (commentaire_id, profil_id) : avec cette
-- clé-là, l'API verrait un lien de plusieurs à plusieurs entre
-- `commentaires` et `profils`, et `commentaires … profils(pseudo)` (les
-- apps déjà installées le demandent ainsi) deviendrait ambigu — les
-- commentaires ne se chargeraient plus. L'unicité, elle, reste.
create table public.commentaires_reactions (
  id uuid primary key default gen_random_uuid(),
  commentaire_id uuid not null references public.commentaires (id) on delete cascade,
  profil_id uuid not null references public.profils (id) on delete cascade,
  cree_le timestamptz not null default now(),
  unique (commentaire_id, profil_id)
);

create index commentaires_reactions_profil
  on public.commentaires_reactions (profil_id);

grant select, insert, delete on public.commentaires_reactions to authenticated;

alter table public.commentaires_reactions enable row level security;

-- Comme les commentaires eux-mêmes : visibles avec leur moment.
create policy "lire les j'aime des commentaires visibles"
  on public.commentaires_reactions for select
  to authenticated
  using (
    exists (
      select 1 from public.commentaires c
      where c.id = commentaires_reactions.commentaire_id
    )
  );

create policy "aimer un commentaire visible"
  on public.commentaires_reactions for insert
  to authenticated
  with check (
    profil_id = auth.uid()
    and exists (
      select 1 from public.commentaires c
      where c.id = commentaires_reactions.commentaire_id
    )
  );

create policy "retirer son j'aime d'un commentaire"
  on public.commentaires_reactions for delete
  to authenticated
  using (profil_id = auth.uid());

-- La fonction `notifier` relit la réponse et le j'aime.
grant select (parent_id) on public.commentaires to service_role;
grant select (commentaire_id, profil_id, cree_le)
  on public.commentaires_reactions to service_role;

-- ------------------------------------------------------------
--  Les notifications. Même corps que
--  `20261027020000_demander_un_avis.sql` (security invoker), plus deux
--  sources et une colonne :
--  - une réponse à mon commentaire ne me revient qu'une fois, en
--    « reponse », même sur mon propre moment ;
--  - un j'aime sur mon commentaire.
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
  commentaire_id uuid,
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
           null::uuid as demande_id, null::uuid as commentaire_id,
           a.cree_le
    from public.abonnements a, moi
    where a.suivi_id = moi.id and a.statut = 'en_attente'
    union all
    select 'nouvel_abonne', a.suiveur_id, null, null, null, null, null, null,
           coalesce(a.accepte_le, a.cree_le)
    from public.abonnements a, moi
    where a.suivi_id = moi.id and a.statut = 'accepte'
    union all
    select 'suivi_accepte', a.suivi_id, null, null, null, null, null, null,
           a.accepte_le
    from public.abonnements a, moi
    where a.suiveur_id = moi.id
      and a.statut = 'accepte'
      and a.accepte_le is not null
      and a.accepte_le > a.cree_le + interval '2 seconds'
    union all
    select 'reaction', r.profil_id, r.souvenir_id, null, null, null, null,
           null, r.cree_le
    from public.reactions r
    join public.souvenirs s on s.id = r.souvenir_id, moi
    where s.auteur_id = moi.id and r.profil_id <> moi.id
    union all
    -- Sur mon moment, sauf une réponse à mon propre commentaire (c'est
    -- une « reponse », juste en dessous).
    select 'commentaire', c.auteur_id, c.souvenir_id, null, c.texte, null,
           null, c.id, c.cree_le
    from public.commentaires c
    join public.souvenirs s on s.id = c.souvenir_id, moi
    where s.auteur_id = moi.id and c.auteur_id <> moi.id
      and not exists (
        select 1 from public.commentaires p
        where p.id = c.parent_id and p.auteur_id = moi.id
      )
    union all
    -- On a répondu à mon commentaire.
    select 'reponse', c.auteur_id, c.souvenir_id, null, c.texte, null, null,
           c.id, c.cree_le
    from public.commentaires c
    join public.commentaires p on p.id = c.parent_id, moi
    where p.auteur_id = moi.id and c.auteur_id <> moi.id
    union all
    -- On a aimé mon commentaire.
    select 'reaction_commentaire', r.profil_id, c.souvenir_id, null, c.texte,
           null, null, c.id, r.cree_le
    from public.commentaires_reactions r
    join public.commentaires c on c.id = r.commentaire_id, moi
    where c.auteur_id = moi.id and r.profil_id <> moi.id
    union all
    -- On me demande mon avis, et je n'ai pas encore répondu.
    select 'demande_avis', d.demandeur_id, null, d.restaurant_id,
           d.message, null, d.id, null, d.cree_le
    from public.demandes_avis d, moi
    where d.destinataire_id = moi.id and d.reponse is null
    union all
    -- On a répondu à ma demande.
    select 'avis_recu', d.destinataire_id, null, d.restaurant_id,
           d.mot, d.reponse, d.id, null, d.repondu_le
    from public.demandes_avis d, moi
    where d.demandeur_id = moi.id
      and d.reponse is not null
      and d.repondu_le is not null
  )
  select e.type, e.acteur_id, p.pseudo, p.photo_url,
         e.souvenir_id, s.photo_url,
         coalesce(e.restaurant_id, s.restaurant_id), r.nom,
         e.texte, e.reponse, e.demande_id, e.commentaire_id, e.cree_le
  from evenements e
  join public.profils p on p.id = e.acteur_id
  left join public.souvenirs s on s.id = e.souvenir_id
  left join public.restaurants r on r.id = coalesce(e.restaurant_id, s.restaurant_id)
  order by e.cree_le desc
  limit least(greatest(p_limite, 1), 200);
$$;

revoke execute on function public.mes_notifications(integer) from public, anon;
grant execute on function public.mes_notifications(integer) to authenticated;
