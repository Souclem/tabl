-- ============================================================
--  Suggestions d'amis
-- ============================================================
--  Demandé le 2026-11-02 : proposer des gens à suivre, dans l'écran
--  Abonnés et de temps en temps au milieu du Feed, avec « Suivre » ou
--  « Suivre en retour ».
--
--  - `suggestions_amis()` : les candidats et ce qui les relie à moi,
--    sans les classer (le classement et les phrases vivent dans l'app,
--    `services/social/suggestion_ami.dart`). Trois liens :
--      · il me suit et je ne le suis pas ;
--      · nous étions dans un même moment (tagué dans un des miens,
--        auteur d'un moment où je suis tagué, ou tagués ensemble) ;
--      · des gens que je suis le suivent (« amis en commun »).
--    Jamais : moi, quelqu'un que je suis ou à qui j'ai demandé,
--    quelqu'un qui attend ma réponse (il est dans « Demandes »), une
--    suggestion écartée.
--    `security definer` : les policies de `abonnements` ne laissent
--    voir que ses propres relations, or « suivi par Emma » lit celles
--    d'Emma. La fonction n'en rend que ce qui me concerne.
--  - `suggestions_ecartees` : le « ✕ » d'une suggestion. Elle ne
--    revient plus ; la personne n'en sait rien et reste trouvable par
--    la recherche.
-- ============================================================

-- Une clé à elle, comme `commentaires_reactions` : avec (profil_id,
-- ecarte_id) pour clé, l'API verrait un lien de plusieurs à plusieurs
-- de `profils` vers lui-même, de quoi rendre ambigus des embeds.
create table public.suggestions_ecartees (
  id uuid primary key default gen_random_uuid(),
  profil_id uuid not null references public.profils (id) on delete cascade,
  ecarte_id uuid not null references public.profils (id) on delete cascade,
  cree_le timestamptz not null default now(),
  unique (profil_id, ecarte_id)
);

create index suggestions_ecartees_ecarte
  on public.suggestions_ecartees (ecarte_id);

grant select, insert on public.suggestions_ecartees to authenticated;

alter table public.suggestions_ecartees enable row level security;

create policy "voir ses suggestions écartées"
  on public.suggestions_ecartees for select
  to authenticated
  using (profil_id = auth.uid());

create policy "écarter une suggestion"
  on public.suggestions_ecartees for insert
  to authenticated
  with check (profil_id = auth.uid());

create or replace function public.suggestions_amis()
returns table (
  profil_id uuid,
  pseudo text,
  photo_url text,
  me_suit boolean,
  moments_communs integer,
  amis_communs integer,
  noms_amis_communs text[]
)
language sql
stable
security definer
set search_path = public
as $$
  with
  -- Ceux que je suis ou à qui j'ai demandé : jamais suggérés.
  mes_suivis as (
    select a.suivi_id as id, a.statut
    from public.abonnements a
    where a.suiveur_id = auth.uid()
  ),
  me_suivent as (
    select a.suiveur_id as id
    from public.abonnements a
    where a.suivi_id = auth.uid() and a.statut = 'accepte'
  ),
  m_attendent as (
    select a.suiveur_id as id
    from public.abonnements a
    where a.suivi_id = auth.uid() and a.statut = 'en_attente'
  ),
  moments as (
    -- Tagués dans mes moments.
    select t.profil_id as id, s.id as souvenir_id
    from public.souvenirs s
    join public.souvenirs_amis_tagues t on t.souvenir_id = s.id
    where s.auteur_id = auth.uid() and s.statut = 'publie'
    union
    -- Auteurs des moments où je suis tagué.
    select s.auteur_id, s.id
    from public.souvenirs s
    join public.souvenirs_amis_tagues t on t.souvenir_id = s.id
    where t.profil_id = auth.uid() and s.statut = 'publie'
    union
    -- Tagués avec moi dans le moment de quelqu'un d'autre.
    select autre.profil_id, s.id
    from public.souvenirs_amis_tagues moi
    join public.souvenirs s on s.id = moi.souvenir_id
    join public.souvenirs_amis_tagues autre on autre.souvenir_id = s.id
    where moi.profil_id = auth.uid() and s.statut = 'publie'
  ),
  -- Suivis par ceux que je suis, avec le pseudo de l'ami en commun.
  amis as (
    select a.suivi_id as id, ami.pseudo
    from mes_suivis ms
    join public.abonnements a
      on a.suiveur_id = ms.id and a.statut = 'accepte'
    join public.profils ami on ami.id = ms.id
    where ms.statut = 'accepte'
  ),
  candidats as (
    select id from me_suivent
    union select id from moments
    union select id from amis
  )
  select
    p.id,
    p.pseudo,
    p.photo_url,
    exists (select 1 from me_suivent x where x.id = p.id),
    (select count(distinct x.souvenir_id) from moments x where x.id = p.id)::int,
    (select count(*) from amis x where x.id = p.id)::int,
    coalesce(
      (select (array_agg(x.pseudo order by x.pseudo))[1:2]
       from amis x where x.id = p.id),
      '{}'
    )
  from candidats c
  join public.profils p on p.id = c.id
  where p.id <> auth.uid()
    and p.id not in (select id from mes_suivis)
    and p.id not in (select id from m_attendent)
    and p.id not in (
      select e.ecarte_id from public.suggestions_ecartees e
      where e.profil_id = auth.uid()
    )
  -- Un garde-fou : l'app n'en montre qu'une dizaine.
  limit 50;
$$;

grant execute on function public.suggestions_amis() to authenticated;
