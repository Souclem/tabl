-- ============================================================
--  Souvenirs : des repas passés, ajoutés après coup
-- ============================================================
--  Un souvenir est une publication comme les autres (même table, mêmes
--  règles de visibilité, réactions, commentaires), mais placée dans le
--  passé : on l'ajoute après coup, à la main ou depuis ses photos. Il
--  se voit sur le profil et la carte, jamais dans le Feed — c'est le
--  Feed qui les écarte, pas la visibilité.
--
--  - `est_souvenir` : ajouté après coup (décision du 2026-10-26 :
--    « la même table en db avec un est_souvenir »).
--  - `jour_connu` : « mars 2023 » suffit pour un souvenir ; la date
--    est alors le 1er du mois, et l'app n'affiche pas le jour.
--  - `souvenirs_photos` : jusqu'à 10 photos par souvenir. La principale
--    reste `souvenirs.photo_url` (Feed, grilles, carte la lisent déjà),
--    les autres sont ici, rangées de 1 à 9 — la clé primaire et la
--    contrainte sur le rang suffisent à en limiter le nombre.
-- ============================================================

alter table public.souvenirs
  add column est_souvenir boolean not null default false,
  add column jour_connu boolean not null default true;

create table public.souvenirs_photos (
  souvenir_id uuid not null references public.souvenirs (id) on delete cascade,
  rang smallint not null check (rang between 1 and 9),
  -- Chemin dans le bucket `souvenirs`, comme `souvenirs.photo_url`.
  chemin text not null,
  primary key (souvenir_id, rang)
);

-- La policy de lecture du bucket cherche une photo par son chemin.
create index souvenirs_photos_chemin on public.souvenirs_photos (chemin);

grant select, insert, delete on public.souvenirs_photos to authenticated;

alter table public.souvenirs_photos enable row level security;

-- Lecture : quiconque peut voir le souvenir (l'auteur compris).
create policy "lire les photos des souvenirs visibles"
  on public.souvenirs_photos for select
  to authenticated
  using (public.peut_voir_souvenir(souvenir_id));

-- Écriture : l'auteur du souvenir seulement.
create policy "ajouter des photos a ses souvenirs"
  on public.souvenirs_photos for insert
  to authenticated
  with check (
    exists (
      select 1 from public.souvenirs s
      where s.id = souvenir_id and s.auteur_id = auth.uid()
    )
  );

create policy "retirer des photos de ses souvenirs"
  on public.souvenirs_photos for delete
  to authenticated
  using (
    exists (
      select 1 from public.souvenirs s
      where s.id = souvenir_id and s.auteur_id = auth.uid()
    )
  );

-- ------------------------------------------------------------
--  Les fichiers du bucket : les photos 2 à 10 se voient comme la
--  principale. Corps identique à
--  `20260919000000_centralisation_storage_souvenirs.sql`, plus
--  `souvenirs_photos`.
-- ------------------------------------------------------------
drop policy "voir les photos des experiences visibles" on storage.objects;

create policy "voir les photos des experiences visibles"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'souvenirs'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1 from public.souvenirs s
        where (s.photo_url = storage.objects.name or s.boisson_photo_url = storage.objects.name)
          and public.peut_voir_souvenir(s.id)
      )
      or exists (
        select 1 from public.souvenirs_photos p
        where p.chemin = storage.objects.name
          and public.peut_voir_souvenir(p.souvenir_id)
      )
    )
  );
