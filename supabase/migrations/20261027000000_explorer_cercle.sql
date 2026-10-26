-- ============================================================
--  Explorer : de quoi raconter chaque adresse
-- ============================================================
--  L'Explorer est refait d'après le prototype (décisions du
--  2026-10-27). Pour l'aperçu d'un lieu, la liste et ses tris
--  (« Récents », « Ils y retournent », « Mieux notés », « Les plus
--  connus »), la carte renvoie désormais, par lieu :
--  - son quartier ;
--  - la dernière visite de mes proches, et combien y sont retournés
--    (deux visites ou plus) ;
--  - leurs ressentis (les emoji, du plus récent au plus ancien) : la
--    note sur 5 est calculée par l'app, pas ici ;
--  - la photo la plus récente qu'on a le droit de voir ;
--  - jusqu'à trois de ces proches (pseudo et photo), les plus fidèles
--    d'abord ;
--  - mes propres visites (combien, la première, la dernière).
--
--  Deux paramètres de plus :
--  - `p_depuis` : seulement les visites depuis cette date (« 3 derniers
--    mois », « 1 an ») ;
--  - `p_mode` : 'cercle' (là où au moins un proche est allé, comme
--    avant), 'envies' (mes envies, même sans proche), 'moi' (là où je
--    suis allé moi-même — « Ma carte »).
--
--  Les colonnes renvoyées changent : la fonction est recréée. Un appel
--  sans les nouveaux paramètres garde le comportement d'avant.
-- ============================================================

drop function if exists public.lieux_carte(
  double precision, double precision, double precision, double precision,
  uuid, uuid, text[], boolean, boolean, boolean, boolean, text, integer
);

create function public.lieux_carte(
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
           s.photo_url,
           s.auteur_id = (select id from moi) as est_moi
    from public.souvenirs s
    join restos r on r.id = s.restaurant_id
    where s.statut = 'publie'
      and (
        s.auteur_id = (select id from moi)
        or s.auteur_id in (select suivi_id from suivis)
        or s.visibilite = 'seulement'
      )
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
  -- Chaque proche, par lieu : combien de fois, et quand la dernière.
  par_ami as (
    select restaurant_id, auteur_id, count(*) as n, max(date_visite) as d
    from visites
    where not est_moi
    group by restaurant_id, auteur_id
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
  from restos r
  left join resume x on x.restaurant_id = r.id
  left join envies e on e.restaurant_id = r.id
  left join visages vi on vi.restaurant_id = r.id
  where case p_mode
          when 'envies' then e.restaurant_id is not null
          when 'moi' then coalesce(x.visite_par_moi, false)
          -- Seulement là où au moins un proche est allé (moi exclu).
          else coalesce(x.amis, 0) > 0
        end
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

grant execute on function public.lieux_carte(
  double precision, double precision, double precision, double precision,
  uuid, uuid, text[], boolean, boolean, boolean, boolean, text, integer,
  date, text
) to authenticated;
