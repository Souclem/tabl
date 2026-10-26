-- ============================================================
--  Lieux personnels : « Chez mes parents », jamais public
-- ============================================================
--  Un souvenir peut se passer ailleurs qu'au restaurant. Un lieu
--  personnel est une ligne `restaurants` marquée `prive` : son nom se
--  lit sur les souvenirs qu'on y a (décision du 2026-10-26, « A » :
--  on partage le moment, pas l'adresse), mais il n'a ni adresse, ni
--  position, ni identifiant d'annuaire — la contrainte le garantit —,
--  donc il n'apparaît sur aucune carte ni autour d'aucune photo. Il
--  n'apparaît pas non plus dans la recherche : seul son auteur le
--  retrouve, dans « Mes lieux ».
-- ============================================================

alter table public.restaurants
  add column prive boolean not null default false;

alter table public.restaurants
  add constraint lieu_personnel_sans_adresse
  check (
    not prive
    or (
      cree_par is not null
      and fsq_place_id is null
      and adresse is null
      and latitude is null
      and longitude is null
    )
  );

-- Retrouver ses propres lieux personnels (« Mes lieux »).
create index if not exists restaurants_lieux_personnels
  on public.restaurants (cree_par)
  where prive;

-- ------------------------------------------------------------
--  La recherche pendant la frappe sans les lieux personnels. Corps
--  identique à `20261017010000_recherche_lieux_nom_contenu.sql`, plus
--  le filtre `not r.prive`.
-- ------------------------------------------------------------
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
                    (word_similarity(q.t, r.nom_recherche)
                     + word_similarity(r.nom_recherche, q.t)) / 2,
                    similarity(q.t, r.nom_recherche)) + 0.05 as score
    from public.restaurants r, q
    where length(q.t) >= 2
      -- Jamais un lieu personnel : ses propres lieux sont proposés à
      -- part par l'app, ceux des autres ne regardent personne.
      and not r.prive
      and (q.t <% r.nom_recherche or r.nom_recherche % q.t)
    union all
    select null, l.fsq_place_id, l.nom, l.adresse, l.ville,
           l.latitude, l.longitude, l.categories,
           greatest(word_similarity(q.t, l.nom_recherche),
                    (word_similarity(q.t, l.nom_recherche)
                     + word_similarity(l.nom_recherche, q.t)) / 2,
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

