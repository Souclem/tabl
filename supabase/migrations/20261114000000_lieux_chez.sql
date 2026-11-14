-- ============================================================
--  Chez moi, chez quelqu'un, ailleurs : jamais localisés
-- ============================================================
--  Décision du 2026-11-14 (feuille « Où et quand », la maison discrète).
--  Un moment hors restaurant reste un lieu personnel
--  (`restaurants.prive`) : la contrainte `lieu_personnel_sans_adresse`
--  lui interdit déjà adresse, position et identifiant d'annuaire, donc
--  il n'apparaît sur aucune carte ni dans aucune liste. On y ajoute :
--
--  - `genre` : 'domicile' (chez moi), 'chez' (chez quelqu'un), 'ailleurs'
--    (pique-nique, travail, voyage, fête). Null : un restaurant, ou un
--    lieu personnel d'avant cette migration (l'app le lit comme 'chez').
--  - `hote_id` : chez quelqu'un de Tabl, qu'on suit. Il est cité, jamais
--    localisé ; il est prévenu (`mes_notifications`, type 'chez_vous')
--    et peut retirer son nom (le lieu redevient « Chez quelqu'un »).
--
--  `mes_notifications()` est recréée (corps de
--  `20261101010000_commentaires_reponses_et_jaime.sql`) avec la source
--  'chez_vous' et une colonne de plus, `restaurant_genre`, pour que les
--  textes disent « chez vous » plutôt que « chez Chez moi ».
-- ============================================================

alter table public.restaurants
  add column genre text,
  add column hote_id uuid references public.profils (id) on delete set null;

alter table public.restaurants
  add constraint restaurants_genre_valide
    check (genre is null or genre in ('domicile', 'chez', 'ailleurs')),
  -- Un genre n'existe que sur un lieu personnel : sans position.
  add constraint restaurants_genre_prive
    check (genre is null or prive),
  add constraint restaurants_hote_chez
    check (
      hote_id is null
      or (prive and genre = 'chez' and hote_id is distinct from cree_par)
    );

-- Les moments chez moi (notifications « chez vous »).
create index if not exists restaurants_hote
  on public.restaurants (hote_id)
  where hote_id is not null;


-- ------------------------------------------------------------
--  Créer : en son nom, et chez quelqu'un qu'on suit seulement
-- ------------------------------------------------------------
--  Corps de 20260823000000 (« en son propre nom »), plus l'hôte : on ne
--  cite pas chez lui un inconnu (ce serait lui envoyer une notification).
drop policy "creer un restaurant" on public.restaurants;
create policy "creer un restaurant"
  on public.restaurants for insert
  to authenticated
  with check (
    auth.uid() = cree_par
    and (hote_id is null or public.abonnement_accepte(hote_id))
  );


-- ------------------------------------------------------------
--  Lire : l'hôte lit le lieu qui le cite
-- ------------------------------------------------------------
--  Corps de 20261103000000, plus `hote_id = auth.uid()`.
drop policy "lire les restaurants" on public.restaurants;
create policy "lire les restaurants"
  on public.restaurants for select
  to authenticated
  using (
    not prive
    or cree_par = auth.uid()
    or hote_id = auth.uid()
    or public.lieu_personnel_visible(id)
  );


-- ------------------------------------------------------------
--  L'hôte retire son nom, et rien d'autre
-- ------------------------------------------------------------
--  Seule modification permise sur `restaurants` : passer `hote_id` à
--  null quand c'est soi. Grant par colonne : aucune autre colonne ne
--  peut changer.
grant update (hote_id) on public.restaurants to authenticated;

create policy "retirer son nom d'un lieu"
  on public.restaurants for update
  to authenticated
  using (hote_id = auth.uid())
  with check (hote_id is null);

-- La fonction `notifier` relit le genre pour écrire « chez vous ».
grant select (genre) on public.restaurants to service_role;


-- ------------------------------------------------------------
--  mes_notifications() : « X a publié un moment chez vous »
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
  cree_le timestamptz,
  restaurant_genre text
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
    union all
    -- On a mangé chez moi. La RLS des moments s'applique (fonction
    -- security invoker) : hors de l'audience, je ne le sais pas.
    select 'chez_vous', s.auteur_id, s.id, null, null, null, null, null,
           s.cree_le
    from public.souvenirs s
    join public.restaurants lieu on lieu.id = s.restaurant_id, moi
    where lieu.hote_id = moi.id
      and s.auteur_id <> moi.id
      and s.statut = 'publie'
  )
  select e.type, e.acteur_id, p.pseudo, p.photo_url,
         e.souvenir_id, s.photo_url,
         coalesce(e.restaurant_id, s.restaurant_id), r.nom,
         e.texte, e.reponse, e.demande_id, e.commentaire_id, e.cree_le,
         r.genre
  from evenements e
  join public.profils p on p.id = e.acteur_id
  left join public.souvenirs s on s.id = e.souvenir_id
  left join public.restaurants r on r.id = coalesce(e.restaurant_id, s.restaurant_id)
  order by e.cree_le desc
  limit least(greatest(p_limite, 1), 200);
$$;

revoke execute on function public.mes_notifications(integer) from public, anon;
grant execute on function public.mes_notifications(integer) to authenticated;
