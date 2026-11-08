-- ============================================================
--  Carte : recherche ciblée sur la zone visible
-- ============================================================
--  Avant : l'app chargeait tous les moments visibles de mon réseau
--  (des milliers) pour tout filtrer et classer elle-même. Désormais la
--  base ne renvoie que la zone visible, filtres appliqués, une ligne
--  résumée par lieu (nombre d'amis, de visites, ami mis en avant...),
--  les plus pertinents d'abord.
--
--  Une seule requête, pas de logique métier hors du filtrage/tri : même
--  esprit que `rechercher_lieux`. `security invoker` : les règles de
--  visibilité (RLS, `peut_voir_souvenir`) s'appliquent exactement comme
--  pour une lecture directe de `souvenirs`.
-- ============================================================

create index if not exists restaurants_position
  on public.restaurants (latitude, longitude);
create index if not exists souvenirs_restaurant
  on public.souvenirs (restaurant_id);
create index if not exists souvenirs_auteur
  on public.souvenirs (auteur_id);
create index if not exists restaurants_sauvegardes_profil
  on public.restaurants_sauvegardes (profil_id);
create index if not exists associations_experience_table_table
  on public.associations_experience_table (table_id);

create or replace function public.lieux_carte(
  p_sud double precision,
  p_ouest double precision,
  p_nord double precision,
  p_est double precision,
  -- Filtres (voir FiltresCarte côté app). `p_categories` : catégories
  -- Foursquare des familles de cuisine choisies, déjà dépliées.
  p_personne uuid default null,
  p_table uuid default null,
  p_categories text[] default null,
  p_mes_envies boolean default false,
  p_jamais_essaye boolean default false,
  p_coups_de_coeur boolean default false,
  p_la_ou_on_revient boolean default false,
  p_moment text default null,
  p_limite integer default 150
)
returns table (
  restaurant_id uuid,
  fsq_place_id text,
  nom text,
  ville text,
  adresse text,
  latitude double precision,
  longitude double precision,
  categories text[],
  amis integer,
  visites integer,
  coups_de_coeur integer,
  visite_par_moi boolean,
  est_envie boolean,
  ami_pseudo text,
  ami_photo text
)
language sql
stable
security invoker
set search_path = public
as $$
  with moi as (
    select auth.uid() as id
  ),
  suivis as (
    select a.suivi_id
    from public.abonnements a, moi
    where a.suiveur_id = moi.id and a.statut = 'accepte'
  ),
  restos as (
    select r.*
    from public.restaurants r
    where r.latitude between p_sud and p_nord
      and r.longitude between p_ouest and p_est
      and (p_categories is null or r.categories && p_categories)
  ),
  -- Mes moments, mes abonnements, et ce qui m'est adressé nommément ou
  -- via une Table (même règle que le Feed) ; la RLS fait le reste.
  visites as (
    select s.id, s.restaurant_id, s.auteur_id, s.date_visite, s.emotion,
           s.auteur_id = (select id from moi) as est_moi
    from public.souvenirs s
    join restos r on r.id = s.restaurant_id
    where s.statut = 'publie'
      and (
        s.auteur_id = (select id from moi)
        or s.auteur_id in (select suivi_id from suivis)
        or s.visibilite = 'seulement'
      )
      and (p_personne is null or s.auteur_id = p_personne)
      and (p_moment is null or s.moment = p_moment)
      and (not p_coups_de_coeur or s.emotion = '😍')
      and (
        p_table is null
        or exists (
          select 1 from public.associations_experience_table a
          where a.souvenir_id = s.id and a.table_id = p_table
        )
      )
  ),
  resume as (
    select v.restaurant_id,
           count(distinct v.auteur_id) filter (where not v.est_moi)::int as amis,
           count(*)::int as visites,
           count(*) filter (where v.emotion = '😍')::int as coups_de_coeur,
           bool_or(v.est_moi) as visite_par_moi
    from visites v
    group by v.restaurant_id
  ),
  -- L'ami mis en avant : celui qui y est allé le plus souvent, le plus
  -- récemment à égalité.
  vedette as (
    select distinct on (v.restaurant_id) v.restaurant_id, v.auteur_id
    from (
      select restaurant_id, auteur_id, count(*) as n, max(date_visite) as d
      from visites where not est_moi
      group by restaurant_id, auteur_id
    ) v
    order by v.restaurant_id, v.n desc, v.d desc
  ),
  envies as (
    select e.restaurant_id
    from public.restaurants_sauvegardes e, moi
    where e.profil_id = moi.id
  )
  select r.id, r.fsq_place_id, r.nom, r.ville, r.adresse,
         r.latitude, r.longitude, r.categories,
         coalesce(x.amis, 0), coalesce(x.visites, 0),
         coalesce(x.coups_de_coeur, 0), coalesce(x.visite_par_moi, false),
         e.restaurant_id is not null,
         p.pseudo, p.photo_url
  from restos r
  left join resume x on x.restaurant_id = r.id
  left join envies e on e.restaurant_id = r.id
  left join vedette ve on ve.restaurant_id = r.id
  left join public.profils p on p.id = ve.auteur_id
  where (x.restaurant_id is not null or e.restaurant_id is not null)
    and (not p_mes_envies or e.restaurant_id is not null)
    and (
      not p_jamais_essaye
      or not exists (
        select 1 from public.souvenirs s, moi
        where s.restaurant_id = r.id and s.auteur_id = moi.id
      )
    )
    -- Filtres portant sur les visites : il en faut au moins une qui
    -- corresponde (deux pour "là où on revient").
    and (
      (p_personne is null and p_table is null and p_moment is null
        and not p_coups_de_coeur and not p_la_ou_on_revient)
      or coalesce(x.visites, 0) >= case when p_la_ou_on_revient then 2 else 1 end
    )
  order by e.restaurant_id is not null desc,
           coalesce(x.amis, 0) desc,
           coalesce(x.visites, 0) desc,
           coalesce(x.coups_de_coeur, 0) desc,
           r.id
  limit least(greatest(p_limite, 1), 500);
$$;

grant execute on function public.lieux_carte(
  double precision, double precision, double precision, double precision,
  uuid, uuid, text[], boolean, boolean, boolean, boolean, text, integer
) to authenticated;
