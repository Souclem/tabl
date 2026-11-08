-- ============================================================
--  Audience d'une publication + profil public/privé
-- ============================================================
--  Décisions produit (2026-10-16) :
--  - Une publication a un mode d'audience parmi trois, exclusifs :
--      'tout_le_monde' : tous ceux qui ont le droit de voir le profil ;
--      'seulement'     : uniquement des Tables et/ou des personnes ;
--      'sauf'          : tout le monde, sauf certaines personnes.
--    Le mot "cercle" disparaît : on dit "Tout le monde".
--  - "Tout le monde" dépend du nouveau réglage `profils.est_prive`
--    (privé par défaut) : privé = abonnés acceptés, public = tout
--    utilisateur connecté.
--  - Une exclusion l'emporte toujours (même si la personne est membre
--    d'une Table associée) — seul l'auteur n'est jamais exclu.
--  - Les membres qui rejoignent plus tard une Table choisie voient le
--    post : c'est déjà le cas, l'association Table reste un grant.
-- ============================================================


-- ------------------------------------------------------------
--  1. Profil privé / public
-- ------------------------------------------------------------
alter table public.profils
  add column est_prive boolean not null default true;


-- ------------------------------------------------------------
--  2. Abonnements : le statut à l'insertion n'est plus libre
-- ------------------------------------------------------------
--  Faille corrigée au passage : la policy d'insertion ne vérifiait que
--  `suiveur_id`, donc n'importe qui pouvait s'insérer directement en
--  statut 'accepte' et lire les publications d'un profil privé sans
--  son accord. Désormais : 'en_attente' toujours permis, 'accepte'
--  seulement vers un profil public (abonnement immédiat, comme
--  Instagram).
drop policy "demander a suivre" on public.abonnements;
create policy "demander a suivre"
  on public.abonnements for insert
  to authenticated
  with check (
    auth.uid() = suiveur_id
    and (
      statut = 'en_attente'
      or (
        statut = 'accepte'
        and exists (
          select 1 from public.profils p
          where p.id = suivi_id and not p.est_prive
        )
      )
    )
  );


-- ------------------------------------------------------------
--  3. Mode d'audience des souvenirs
-- ------------------------------------------------------------
--  'cercle' devient 'tout_le_monde' ; 'prive' (Table(s) uniquement)
--  devient 'seulement', les Tables associées restant le grant.
alter table public.souvenirs drop constraint souvenirs_visibilite_check;
update public.souvenirs
  set visibilite = case visibilite
    when 'cercle' then 'tout_le_monde'
    else 'seulement'
  end;
alter table public.souvenirs
  alter column visibilite set default 'tout_le_monde',
  add constraint souvenirs_visibilite_check
    check (visibilite in ('tout_le_monde', 'seulement', 'sauf'));


-- ------------------------------------------------------------
--  4. Personnes choisies pour un souvenir
-- ------------------------------------------------------------
--  Une seule liste, interprétée selon le mode : personnes autorisées
--  en 'seulement', personnes exclues en 'sauf', ignorée en
--  'tout_le_monde'. Lisible par l'auteur seul : une personne exclue ne
--  doit jamais pouvoir découvrir qu'elle l'est.
create table public.souvenirs_audience (
  souvenir_id uuid not null references public.souvenirs (id) on delete cascade,
  profil_id uuid not null references public.profils (id) on delete cascade,
  primary key (souvenir_id, profil_id)
);

grant select, insert, delete on public.souvenirs_audience to authenticated;
alter table public.souvenirs_audience enable row level security;

create policy "lire l'audience de ses souvenirs"
  on public.souvenirs_audience for select
  to authenticated
  using (
    exists (
      select 1 from public.souvenirs s
      where s.id = souvenirs_audience.souvenir_id and s.auteur_id = auth.uid()
    )
  );

create policy "choisir l'audience de ses souvenirs"
  on public.souvenirs_audience for insert
  to authenticated
  with check (
    exists (
      select 1 from public.souvenirs s
      where s.id = souvenirs_audience.souvenir_id and s.auteur_id = auth.uid()
    )
  );

create policy "retirer de l'audience de ses souvenirs"
  on public.souvenirs_audience for delete
  to authenticated
  using (
    exists (
      select 1 from public.souvenirs s
      where s.id = souvenirs_audience.souvenir_id and s.auteur_id = auth.uid()
    )
  );


-- ------------------------------------------------------------
--  5. La règle de visibilité, toujours en un seul endroit
-- ------------------------------------------------------------
--  Même signature, donc la policy `souvenirs` et les policies Storage
--  qui l'appellent suivent sans modification.
create or replace function public.peut_voir_souvenir(p_souvenir_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.souvenirs s
    where s.id = p_souvenir_id
      and (
        -- Auteur : toujours, quel que soit le statut (brouillon inclus).
        s.auteur_id = auth.uid()
        or (
          s.statut = 'publie'
          -- Une exclusion l'emporte sur tout le reste.
          and not (
            s.visibilite = 'sauf'
            and exists (
              select 1 from public.souvenirs_audience au
              where au.souvenir_id = s.id and au.profil_id = auth.uid()
            )
          )
          and (
            -- "Tout le monde" (avec ou sans exclusions) : les abonnés
            -- acceptés si le profil est privé, tout le monde sinon.
            (
              s.visibilite in ('tout_le_monde', 'sauf')
              and (
                public.abonnement_accepte(s.auteur_id)
                or exists (
                  select 1 from public.profils p
                  where p.id = s.auteur_id and not p.est_prive
                )
              )
            )
            -- "Seulement…" : personne choisie nommément.
            or (
              s.visibilite = 'seulement'
              and exists (
                select 1 from public.souvenirs_audience au
                where au.souvenir_id = s.id and au.profil_id = auth.uid()
              )
            )
            -- Table associée : membre actif, y compris arrivé après la
            -- publication.
            or exists (
              select 1
              from public.associations_experience_table a
              join public.membres_table m
                on m.table_id = a.table_id
                and m.profil_id = auth.uid()
                and m.statut = 'active'
              where a.souvenir_id = s.id
            )
          )
        )
      )
  );
$$;


-- ------------------------------------------------------------
--  6. Réseau étendu (Explorer) : 'cercle' → 'tout_le_monde'
-- ------------------------------------------------------------
--  Corps identique à `20260917000000_carte_explorer.sql`, seule la
--  valeur de visibilité change.
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
    and s.visibilite = 'tout_le_monde'
    and ada.ami_id <> auth.uid()
    and ada.ami_id not in (select ami_id from amis_directs)
  group by s.restaurant_id;
$$;
