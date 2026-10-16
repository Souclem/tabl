-- ============================================================
--  Annuaire des lieux + restaurants géolocalisés
-- ============================================================
--  Deux tables, deux rôles (décision du 2026-10-16) :
--  - `lieux_reference` : l'annuaire, importé de Foursquare OS Places
--    (Apache 2.0, stockage autorisé), remplacé à chaque import. On ne
--    fait que chercher dedans ; il alimente aussi la carte (lieux où
--    personne de Tabl n'est encore allé).
--  - `restaurants` : uniquement les lieux entrés dans Tabl (publiés, mis
--    en envie, proposés à une Table). C'est à eux que tout est lié. Un
--    lieu de l'annuaire y est recopié la première fois qu'il sert, en
--    gardant `fsq_place_id` pour ne jamais créer de doublon.
-- ============================================================

create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;


-- ------------------------------------------------------------
--  1. L'annuaire
-- ------------------------------------------------------------
create table public.lieux_reference (
  fsq_place_id text primary key,
  nom text not null,
  adresse text,
  ville text,
  code_postal text,
  pays text not null,
  latitude double precision not null,
  longitude double precision not null,
  -- Catégories feuilles Foursquare ("Italian Restaurant", "Brasserie"...).
  categories text[] not null default '{}',
  rafraichi_le date,
  -- Nom en minuscules sans accents, calculé à l'import : `unaccent`
  -- n'est pas immuable, il ne peut pas servir de colonne générée.
  nom_recherche text not null
);

create index lieux_reference_nom_trgm
  on public.lieux_reference using gin (nom_recherche extensions.gin_trgm_ops);
create index lieux_reference_position
  on public.lieux_reference (latitude, longitude);

grant select on public.lieux_reference to authenticated;
alter table public.lieux_reference enable row level security;

create policy "lire l'annuaire"
  on public.lieux_reference for select
  to authenticated
  using (true);


-- ------------------------------------------------------------
--  2. Restaurants de Tabl : lien vers l'annuaire et détails
-- ------------------------------------------------------------
alter table public.restaurants
  add column fsq_place_id text unique,
  add column adresse text,
  add column categories text[] not null default '{}',
  add column nom_recherche text;

update public.restaurants
  set nom_recherche = lower(extensions.unaccent(nom));

create index restaurants_nom_trgm
  on public.restaurants using gin (nom_recherche extensions.gin_trgm_ops);


-- ------------------------------------------------------------
--  3. Recherche pendant la frappe
-- ------------------------------------------------------------
--  Une seule requête, pas de logique métier : les lieux déjà dans Tabl
--  (y compris ajoutés à la main, ou hors des pays importés) d'abord à
--  pertinence égale, puis l'annuaire, sans doublon. Tolère les mots en
--  plus ou en moins ("le campus brasserie" trouve "Le Campus") et les
--  accents. Les fiches de l'annuaire non rafraîchies depuis longtemps
--  descendent légèrement (peut-être fermées sans que la base le sache).
create or replace function public.rechercher_lieux(
  p_texte text,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_limite integer default 8
)
returns table (
  restaurant_id uuid,
  fsq_place_id text,
  nom text,
  adresse text,
  ville text,
  latitude double precision,
  longitude double precision,
  categories text[],
  distance_m double precision
)
language sql
stable
set search_path = public, extensions
as $$
  with q as (
    select lower(unaccent(trim(p_texte))) as t
  ),
  candidats as (
    select r.id as restaurant_id, r.fsq_place_id, r.nom, r.adresse, r.ville,
           r.latitude, r.longitude, r.categories,
           greatest(word_similarity(q.t, r.nom_recherche),
                    similarity(q.t, r.nom_recherche)) + 0.05 as score
    from public.restaurants r, q
    where length(q.t) >= 2
      and (q.t <% r.nom_recherche or r.nom_recherche % q.t)
    union all
    select null, l.fsq_place_id, l.nom, l.adresse, l.ville,
           l.latitude, l.longitude, l.categories,
           greatest(word_similarity(q.t, l.nom_recherche),
                    similarity(q.t, l.nom_recherche))
             - case when l.rafraichi_le < date '2023-01-01' then 0.1 else 0 end
    from public.lieux_reference l, q
    where length(q.t) >= 2
      and (q.t <% l.nom_recherche or l.nom_recherche % q.t)
      and not exists (
        select 1 from public.restaurants r where r.fsq_place_id = l.fsq_place_id
      )
  ),
  avec_distance as (
    select c.*,
      case when p_latitude is null or c.latitude is null then null
      else 6371000 * 2 * asin(sqrt(
        power(sin(radians(c.latitude - p_latitude) / 2), 2)
        + cos(radians(p_latitude)) * cos(radians(c.latitude))
          * power(sin(radians(c.longitude - p_longitude) / 2), 2)
      )) end as distance_m
    from candidats c
  )
  select restaurant_id, fsq_place_id, nom, adresse, ville, latitude, longitude,
         categories, distance_m
  from avec_distance
  -- Pertinence d'abord (par paliers, pour que la proximité départage
  -- les noms aussi ressemblants), puis le plus proche.
  order by round((score * 10)::numeric) desc, distance_m asc nulls last, score desc
  limit least(greatest(p_limite, 1), 20);
$$;

grant execute on function public.rechercher_lieux(text, double precision, double precision, integer)
  to authenticated;
