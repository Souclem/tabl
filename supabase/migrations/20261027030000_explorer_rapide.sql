-- ============================================================
--  Explorer : la carte de nouveau rapide
-- ============================================================
--  `20261027000000_explorer_cercle.sql` (et avant elle
--  `20261022000000_carte_amis_seulement.sql`) était repartie de la
--  version `security invoker` : la RLS de `souvenirs` vérifiait alors la
--  visibilité (`peut_voir_souvenir`) de TOUS les moments des
--  restaurants de la zone — et l'app demande désormais le monde entier —,
--  y compris ceux de personnes que je ne suis pas, écartés juste après.
--  Résultat : « canceling statement due to statement timeout », et
--  l'Explorer qui ne charge plus.
--
--  Même remède que `20261017040000_recherche_carte_rapide.sql` :
--  `security definer`, la fonction sélectionne d'abord les moments de
--  mon réseau, PUIS vérifie chacun avec la même règle centrale
--  `peut_voir_souvenir` (rien n'est dupliqué, rien n'est relâché).
--  `auth.uid()` reste celui de l'appelant. Les restaurants sont lisibles
--  par tous (policy « lire les restaurants ») ; un lieu personnel n'a
--  pas de position, il reste hors de toute zone.
--
--  Et la requête part de ce qui compte (mes visites, celles du réseau,
--  mes envies) au lieu de tous les restaurants de la zone.
--
--  Même signature, mêmes colonnes, même comportement.
-- ============================================================

create or replace function public.lieux_carte(
  p_sud double precision,
  p_ouest double precision,
  p_nord double precision,
  p_est double precision,
  p_personne uuid default null,
  p_table uuid default null,
  p_categories text[] default null,
  p_mes_envies boolean default false,
  p_jamais_essaye boolean default false,
  p_coups_de_coeur boolean default false,
  p_la_ou_on_revient boolean default false,
  p_moment text default null,
  p_limite integer default 150,
  p_depuis date default null,
  p_mode text default 'cercle'
)
returns table (
  restaurant_id uuid,
  fsq_place_id text,
  nom text,
  ville text,
  quartier text,
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
  ami_photo text,
  amis_qui_reviennent integer,
  derniere_visite date,
  ressentis text[],
  photo text,
  visages_pseudos text[],
  visages_photos text[],
  mes_visites integer,
  ma_premiere_visite date,
  ma_derniere_visite date
)
language sql
stable
security definer
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
  -- Mes moments, mes abonnements, et ce qui m'est adressé nommément
  -- (même règle que le Feed), dans la zone et les filtres…
  candidates as materialized (
    select s.id, s.restaurant_id, s.auteur_id, s.date_visite, s.emotion,
           s.photo_url,
           s.auteur_id = (select id from moi) as est_moi
    from public.souvenirs s
    join public.restaurants r on r.id = s.restaurant_id
    where s.statut = 'publie'
      and (
        s.auteur_id = (select id from moi)
        or s.auteur_id in (select suivi_id from suivis)
        or s.visibilite = 'seulement'
      )
      and r.latitude between p_sud and p_nord
      and r.longitude between p_ouest and p_est
      and (p_categories is null or r.categories && p_categories)
      and (p_depuis is null or s.date_visite >= p_depuis)
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
  -- …puis la règle de visibilité, la même que partout
  -- (`peut_voir_souvenir`), vérifiée seulement sur ces moments-là. Les
  -- miens, je les vois toujours.
  visites as materialized (
    select * from candidates c
    where c.est_moi or public.peut_voir_souvenir(c.id)
  ),
  -- Chaque proche, par lieu : combien de fois, et quand la dernière.
  par_ami as (
    select v.restaurant_id, v.auteur_id, count(*) as n,
           max(v.date_visite) as d
    from visites v
    where not v.est_moi
    group by v.restaurant_id, v.auteur_id
  ),
  resume as (
    select v.restaurant_id,
           count(distinct v.auteur_id) filter (where not v.est_moi)::int as amis,
           count(*)::int as visites,
           count(*) filter (where v.emotion = '😍')::int as coups_de_coeur,
           bool_or(v.est_moi) as visite_par_moi,
           max(v.date_visite) filter (where not v.est_moi) as derniere_visite,
           coalesce(
             array_agg(v.emotion order by v.date_visite desc, v.id)
               filter (where not v.est_moi and v.emotion is not null),
             '{}'
           ) as ressentis,
           (array_agg(v.photo_url order by v.date_visite desc, v.id)
              filter (where v.photo_url is not null))[1] as photo,
           count(*) filter (where v.est_moi)::int as mes_visites,
           min(v.date_visite) filter (where v.est_moi) as ma_premiere_visite,
           max(v.date_visite) filter (where v.est_moi) as ma_derniere_visite
    from visites v
    group by v.restaurant_id
  ),
  -- Les proches mis en avant : les plus fidèles, les plus récents à
  -- égalité ; et combien y sont retournés.
  visages as (
    select pa.restaurant_id,
           (array_agg(p.pseudo order by pa.n desc, pa.d desc, p.id))[1:3]
             as pseudos,
           (array_agg(coalesce(p.photo_url, '') order by pa.n desc, pa.d desc, p.id))[1:3]
             as photos,
           count(*) filter (where pa.n >= 2)::int as revenants
    from par_ami pa
    join public.profils p on p.id = pa.auteur_id
    group by pa.restaurant_id
  ),
  envies as (
    select e.restaurant_id
    from public.restaurants_sauvegardes e, moi
    where e.profil_id = moi.id
  ),
  -- Les lieux du mode : là où au moins un proche est allé (moi exclu),
  -- là où je suis allé moi-même (« Ma carte »), ou mes envies.
  choisis as (
    select x.restaurant_id
    from resume x
    where case coalesce(p_mode, 'cercle')
            when 'envies' then false
            when 'moi' then x.visite_par_moi
            else x.amis > 0
          end
    union
    select e.restaurant_id
    from envies e
    where p_mode = 'envies'
  )
  select r.id, r.fsq_place_id, r.nom, r.ville, r.quartier, r.adresse,
         r.latitude, r.longitude, r.categories,
         coalesce(x.amis, 0), coalesce(x.visites, 0),
         coalesce(x.coups_de_coeur, 0), coalesce(x.visite_par_moi, false),
         e.restaurant_id is not null,
         vi.pseudos[1], nullif(vi.photos[1], ''),
         coalesce(vi.revenants, 0),
         x.derniere_visite,
         coalesce(x.ressentis, '{}'),
         x.photo,
         coalesce(vi.pseudos, '{}'),
         coalesce(vi.photos, '{}'),
         coalesce(x.mes_visites, 0),
         x.ma_premiere_visite,
         x.ma_derniere_visite
  from choisis c
  join public.restaurants r on r.id = c.restaurant_id
  left join resume x on x.restaurant_id = r.id
  left join envies e on e.restaurant_id = r.id
  left join visages vi on vi.restaurant_id = r.id
  where r.latitude between p_sud and p_nord
    and r.longitude between p_ouest and p_est
    and (p_categories is null or r.categories && p_categories)
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
        and p_depuis is null and not p_coups_de_coeur
        and not p_la_ou_on_revient)
      or coalesce(x.visites, 0) >= case when p_la_ou_on_revient then 2 else 1 end
    )
  order by e.restaurant_id is not null desc,
           coalesce(x.amis, 0) desc,
           coalesce(x.visites, 0) desc,
           coalesce(x.coups_de_coeur, 0) desc,
           r.id
  limit least(greatest(p_limite, 1), 5000);
$$;

-- `security definer` : personne d'autre que les connectés.
revoke execute on function public.lieux_carte(
  double precision, double precision, double precision, double precision,
  uuid, uuid, text[], boolean, boolean, boolean, boolean, text, integer,
  date, text
) from public, anon;
grant execute on function public.lieux_carte(
  double precision, double precision, double precision, double precision,
  uuid, uuid, text[], boolean, boolean, boolean, boolean, text, integer,
  date, text
) to authenticated;
