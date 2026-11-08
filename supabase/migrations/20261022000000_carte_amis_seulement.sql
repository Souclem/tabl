-- ============================================================
--  Carte : seulement les restaurants où mes amis sont allés
-- ============================================================
--  Décision du 2026-10-22. La carte regroupe désormais les lieux en
--  bulles chiffrées (« 42 » sur une ville, « 3 », « 2 », « 5 » par
--  quartier en zoomant) : ce chiffre compte les restaurants où au moins
--  un ami est allé. Ceux où seuls moi ou mes envies menaient ne sont
--  plus renvoyés, ni l'annuaire (côté app).
--
--  Pour que ces chiffres soient justes, l'app charge tous ces lieux
--  d'un coup (le monde entier) et non plus la seule zone visible : la
--  limite passe de 500 à 5 000 lignes.
--
--  Même signature et mêmes colonnes : seuls le filtre final et la
--  limite changent (voir 20261017030000_recherche_carte_ciblee.sql).
-- ============================================================

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
  -- Seulement là où au moins un ami est allé (moi exclu).
  where coalesce(x.amis, 0) > 0
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
  limit least(greatest(p_limite, 1), 5000);
$$;

grant execute on function public.lieux_carte(
  double precision, double precision, double precision, double precision,
  uuid, uuid, text[], boolean, boolean, boolean, boolean, text, integer
) to authenticated;
