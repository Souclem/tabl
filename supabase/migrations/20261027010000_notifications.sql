-- ============================================================
--  Notifications : les bases (demande de suivi, j'aime, commentaire,
--  suivi accepté)
-- ============================================================
--  Demandé le 2026-10-27 : « les plus basiques ». Pas de table de
--  notifications remplie par des triggers (pas de logique en base) :
--  une notification est lue là où l'événement est déjà écrit — une
--  demande dans `abonnements`, un j'aime dans `reactions`, un
--  commentaire dans `commentaires`. Un j'aime retiré, un commentaire
--  supprimé, une demande refusée : la notification disparaît d'elle-même.
--
--  Deux colonnes de plus :
--  - `abonnements.accepte_le` : quand le suivi a été accepté (posé par
--    l'app en acceptant). Sert à « Martin a accepté votre demande » ;
--    vide pour les demandes en attente. Les suivis déjà acceptés
--    reprennent leur date de création.
--  - `profils.notifications_vues_le` : jusqu'où j'ai lu mes
--    notifications (la pastille de la cloche).
--
--  `mes_notifications()` les rassemble, les plus récentes d'abord ; la
--  RLS de chaque table s'applique (security invoker) : on ne voit que
--  ce qui concerne ses propres souvenirs et ses propres abonnements.
-- ============================================================

alter table public.abonnements add column accepte_le timestamptz;

update public.abonnements set accepte_le = cree_le where statut = 'accepte';

alter table public.profils add column notifications_vues_le timestamptz;

-- Les abonnés et demandes d'un profil, du plus récent au plus ancien.
create index if not exists abonnements_suivi_recents
  on public.abonnements (suivi_id, cree_le desc);

-- Les j'aime d'un souvenir, du plus récent au plus ancien.
create index if not exists reactions_souvenir_recents
  on public.reactions (souvenir_id, cree_le desc);

create or replace function public.mes_notifications(p_limite integer default 80)
returns table (
  type text,
  acteur_id uuid,
  acteur_pseudo text,
  acteur_photo text,
  souvenir_id uuid,
  souvenir_photo text,
  restaurant_nom text,
  texte text,
  cree_le timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  with moi as (select auth.uid() as id),
  evenements as (
    -- Quelqu'un demande à me suivre.
    select 'demande_suivi' as type, a.suiveur_id as acteur_id,
           null::uuid as souvenir_id, null::text as texte, a.cree_le
    from public.abonnements a, moi
    where a.suivi_id = moi.id and a.statut = 'en_attente'
    union all
    -- Quelqu'un me suit (profil public, ou demande que j'ai acceptée).
    select 'nouvel_abonne', a.suiveur_id, null, null,
           coalesce(a.accepte_le, a.cree_le)
    from public.abonnements a, moi
    where a.suivi_id = moi.id and a.statut = 'accepte'
    union all
    -- On a accepté ma demande (pas un suivi immédiat d'un profil public).
    select 'suivi_accepte', a.suivi_id, null, null, a.accepte_le
    from public.abonnements a, moi
    where a.suiveur_id = moi.id
      and a.statut = 'accepte'
      and a.accepte_le is not null
      and a.accepte_le > a.cree_le + interval '2 seconds'
    union all
    -- J'aime sur l'un de mes souvenirs.
    select 'reaction', r.profil_id, r.souvenir_id, null, r.cree_le
    from public.reactions r
    join public.souvenirs s on s.id = r.souvenir_id, moi
    where s.auteur_id = moi.id and r.profil_id <> moi.id
    union all
    -- Commentaire sur l'un de mes souvenirs.
    select 'commentaire', c.auteur_id, c.souvenir_id, c.texte, c.cree_le
    from public.commentaires c
    join public.souvenirs s on s.id = c.souvenir_id, moi
    where s.auteur_id = moi.id and c.auteur_id <> moi.id
  )
  select e.type, e.acteur_id, p.pseudo, p.photo_url,
         e.souvenir_id, s.photo_url, r.nom, e.texte, e.cree_le
  from evenements e
  join public.profils p on p.id = e.acteur_id
  left join public.souvenirs s on s.id = e.souvenir_id
  left join public.restaurants r on r.id = s.restaurant_id
  order by e.cree_le desc
  limit least(greatest(p_limite, 1), 200);
$$;

revoke execute on function public.mes_notifications(integer) from public, anon;
grant execute on function public.mes_notifications(integer) to authenticated;
