-- ============================================================
--  Recherche de lieux : quand le nom est contenu dans la recherche
-- ============================================================
--  « le campus brasserie » proposait « Brasserie Le Cap » (Marche)
--  avant « Le Campus » (Liège) : seul comptait « la recherche est-elle
--  dans le nom ? », jamais l'inverse. On ajoute la moyenne des deux
--  sens — pas l'inverse seul, sinon un nom très court (« En », « Co »)
--  serait « contenu » dans presque toute recherche. À score égal, la
--  proximité départage, comme avant. Seul le calcul du score change.
-- ============================================================

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

