-- ============================================================
--  Explorer / Carte — restaurants gardés + agrégats réseau étendu
-- ============================================================
--  `restaurants` (avec latitude/longitude) et `souvenirs.restaurant_id`
--  existent déjà depuis la migration
--  `20260823000000_abonnements_restaurants_souvenirs.sql` : rien à
--  ajouter côté modèle de restaurant lui-même.
--
--  Ce qui manque pour l'écran Explorer (voir
--  `instruction/Copy of Clément + After reunion/scraps/megaprompt.txt`,
--  BLOC 1) :
--  1. Un lieu "gardé" (bouton Garder / Gardé ✓ de la preview carte, mode
--     Envies) — pas encore de table pour ça.
--  2. Le compte anonymisé du réseau étendu (amis d'amis) par restaurant,
--     pour la portée sociale Premium. La règle produit est absolue :
--     jamais exposer l'identité d'un ami d'ami, seulement un total. La
--     table `souvenirs` restreint déjà sa lecture (RLS) à l'auteur et à
--     son cercle direct — un utilisateur ne peut donc pas calculer ce
--     compte lui-même côté client en lisant `souvenirs` ligne à ligne,
--     même agrégé, puisque les lignes des amis d'amis ne lui sont
--     jamais retournées. Il faut un calcul côté serveur qui ne renvoie
--     que l'agrégat. `abonnement_accepte` (migration
--     `20260825000000_corrections_revue.sql`) établit déjà ce
--     précédent : une fonction SQL déclarative (pas de PL/pgSQL, pas de
--     boucle, pas de logique métier procédurale — juste une requête),
--     ici en `security definer` puisqu'elle doit lire au-delà de ce que
--     RLS autoriserait normalement pour l'appelant, mais elle ne
--     retourne qu'un entier par restaurant, jamais une ligne identifiable.
-- ============================================================

create table public.restaurants_sauvegardes (
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  profil_id uuid not null references public.profils (id) on delete cascade,
  cree_le timestamptz not null default now(),

  primary key (restaurant_id, profil_id)
);

grant select, insert, delete on public.restaurants_sauvegardes to authenticated;

alter table public.restaurants_sauvegardes enable row level security;

create policy "lire ses restaurants gardes"
  on public.restaurants_sauvegardes for select
  to authenticated
  using (profil_id = auth.uid());

create policy "garder un restaurant"
  on public.restaurants_sauvegardes for insert
  to authenticated
  with check (profil_id = auth.uid());

create policy "retirer un restaurant garde"
  on public.restaurants_sauvegardes for delete
  to authenticated
  using (profil_id = auth.uid());


-- ============================================================
--  Réseau étendu (amis d'amis) : compte anonymisé par restaurant
-- ============================================================
--  Amis directs = relations `abonnements` acceptées avec moi (peu
--  importe le sens, cf. `AbonnementService.mesAmis`). Amis d'amis =
--  quiconque a une relation acceptée avec un de mes amis directs, en
--  excluant moi-même et mes amis directs. Le compte ne porte que sur
--  les souvenirs publiés et partagés au cercle (jamais les souvenirs
--  privés d'un ami d'ami, même si techniquement lisibles par lui).
-- ============================================================

create or replace function public.comptes_reseau_etendu(ids uuid[])
returns table (restaurant_id uuid, compte integer)
language sql
stable
security definer
set search_path = public
as $$
  with amis_directs as (
    select case when a.suiveur_id = auth.uid() then a.suivi_id else a.suiveur_id end as ami_id
    from public.abonnements a
    where a.statut = 'accepte'
      and (a.suiveur_id = auth.uid() or a.suivi_id = auth.uid())
  ),
  amis_des_amis as (
    select distinct
      case when a.suiveur_id = ad.ami_id then a.suivi_id else a.suiveur_id end as ami_id
    from public.abonnements a
    join amis_directs ad
      on a.suiveur_id = ad.ami_id or a.suivi_id = ad.ami_id
    where a.statut = 'accepte'
  )
  select s.restaurant_id, count(distinct s.auteur_id)::int as compte
  from public.souvenirs s
  join amis_des_amis ada on ada.ami_id = s.auteur_id
  where s.restaurant_id = any(ids)
    and s.statut = 'publie'
    and s.visibilite = 'cercle'
    and ada.ami_id <> auth.uid()
    and ada.ami_id not in (select ami_id from amis_directs)
  group by s.restaurant_id;
$$;

grant execute on function public.comptes_reseau_etendu(uuid[]) to authenticated;
