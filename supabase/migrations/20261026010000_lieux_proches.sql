-- ============================================================
--  Les restaurants autour d'un point (une photo de souvenir)
-- ============================================================
--  Un souvenir ajouté depuis ses photos propose le restaurant le plus
--  proche de l'endroit où elles ont été prises, avec sa distance ;
--  l'utilisateur peut en changer. Une seule requête, sans logique
--  métier : les lieux déjà dans Tabl et ceux de l'annuaire (sans
--  doublon) dans un carré autour du point — les index sur la position
--  servent —, puis seulement ceux du cercle, du plus proche au plus
--  loin. Mêmes colonnes que `rechercher_lieux`.
-- ============================================================

create or replace function public.lieux_proches(
  p_latitude double precision,
  p_longitude double precision,
  p_rayon_m double precision default 250,
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
set search_path = public
as $$
  with carre as (
    select least(greatest(p_rayon_m, 10), 2000) as rayon,
           least(greatest(p_rayon_m, 10), 2000) / 111320.0 as dlat,
           least(greatest(p_rayon_m, 10), 2000)
             / (111320.0 * greatest(cos(radians(p_latitude)), 0.01)) as dlng
  ),
  candidats as (
    select r.id as restaurant_id, r.fsq_place_id, r.nom, r.adresse, r.ville,
           r.latitude, r.longitude, r.categories
    from public.restaurants r, carre c
    where r.latitude between p_latitude - c.dlat and p_latitude + c.dlat
      and r.longitude between p_longitude - c.dlng and p_longitude + c.dlng
    union all
    select null, l.fsq_place_id, l.nom, l.adresse, l.ville,
           l.latitude, l.longitude, l.categories
    from public.lieux_reference l, carre c
    where l.latitude between p_latitude - c.dlat and p_latitude + c.dlat
      and l.longitude between p_longitude - c.dlng and p_longitude + c.dlng
      and not exists (
        select 1 from public.restaurants r where r.fsq_place_id = l.fsq_place_id
      )
  ),
  avec_distance as (
    select ca.*,
      6371000 * 2 * asin(sqrt(
        power(sin(radians(ca.latitude - p_latitude) / 2), 2)
        + cos(radians(p_latitude)) * cos(radians(ca.latitude))
          * power(sin(radians(ca.longitude - p_longitude) / 2), 2)
      )) as distance_m
    from candidats ca
  )
  select restaurant_id, fsq_place_id, nom, adresse, ville, latitude, longitude,
         categories, distance_m
  from avec_distance, carre c
  where distance_m <= c.rayon
  order by distance_m
  limit least(greatest(p_limite, 1), 20);
$$;

revoke execute on function public.lieux_proches(double precision, double precision, double precision, integer) from public, anon;
grant execute on function public.lieux_proches(double precision, double precision, double precision, integer) to authenticated;
