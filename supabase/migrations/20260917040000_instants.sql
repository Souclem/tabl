-- ============================================================
--  Instants — fragment vivant et temporaire d'une expérience déjà
--  publiée (megaprompt Bloc 2, dernier des 5 blocs)
-- ============================================================
--  Construit après le Bloc 5 pour une seule raison : l'audience d'un
--  Instant est TOUJOURS celle du parent (règle 32-33 — "la logique
--  exacte audience/Table est traitée dans le Bloc Publication, ne pas
--  refactorer ce bloc ici"). `peut_voir_souvenir()` (migration
--  `20260917030000_visibilite_experience_centralisee.sql`) existe déjà
--  et couvre cercle direct + toutes les Tables — les policies
--  ci-dessous s'y branchent directement, aucune logique de visibilité
--  séparée n'est réinventée.
--
--  `upload_state` (règle 26-28) n'est PAS une colonne ici, volontairement :
--  le pattern déjà établi par `souvenirs`/`enregistrerBrouillon` est que
--  la ligne n'existe qu'une fois le média effectivement déposé dans le
--  bucket — la même convention est reprise pour `instants`. Les états
--  queued/uploading/failed sont donc purement côté client (avant que la
--  ligne existe), pas persistés — cohérent avec l'existant, pas une
--  simplification propre à ce bloc.
-- ============================================================

create table public.instants (
  id uuid primary key default gen_random_uuid(),

  parent_experience_id uuid not null references public.souvenirs (id) on delete cascade,
  owner_user_id uuid not null references public.profils (id) on delete cascade,

  media_type text not null check (media_type in ('photo', 'video')),
  -- Chemin dans le bucket `instants` (comme `souvenirs.photo_url`), pas
  -- une URL signée — résolue à l'affichage, jamais stockée expirable.
  media_url text not null,

  cree_le timestamptz not null default now(),
  -- Règle 5 : par média, pas par expérience — deux Instants du même
  -- parent peuvent expirer à des moments différents.
  expire_socialement_le timestamptz not null
);

grant select, insert, delete on public.instants to authenticated;

alter table public.instants enable row level security;

-- Lecture (règle 32-33) : le propriétaire toujours, ou quiconque peut
-- voir l'expérience parente — exactement la même règle que "Notre
-- histoire" au Bloc 3/5, aucune logique de visibilité spécifique aux
-- Instants.
create policy "lire les instants des experiences visibles"
  on public.instants for select
  to authenticated
  using (
    owner_user_id = auth.uid()
    or public.peut_voir_souvenir(parent_experience_id)
  );

-- Création (règle 3) : uniquement le propriétaire de l'expérience
-- parente. La fenêtre de 6h et la limite de 6 actifs (règle 4, 29) sont
-- validées côté service (Dart), pas en contrainte SQL : ce sont des
-- règles produit configurables et relatives à `now()`, pas des
-- invariants de données immuables.
create policy "creer un instant sur sa propre experience"
  on public.instants for insert
  to authenticated
  with check (
    owner_user_id = auth.uid()
    and exists (
      select 1 from public.souvenirs s
      where s.id = parent_experience_id and s.auteur_id = auth.uid()
    )
  );

-- Suppression (règle 30) : le propriétaire uniquement.
create policy "supprimer son propre instant"
  on public.instants for delete
  to authenticated
  using (owner_user_id = auth.uid());


-- ============================================================
--  instant_vues — seen state PAR VIEWER (règle 68), jamais global
-- ============================================================

create table public.instant_vues (
  instant_id uuid not null references public.instants (id) on delete cascade,
  profil_id uuid not null references public.profils (id) on delete cascade,
  vu_le timestamptz not null default now(),

  primary key (instant_id, profil_id)
);

grant select, insert on public.instant_vues to authenticated;

alter table public.instant_vues enable row level security;

-- Règle 48 : pas de viewer count public — chacun ne lit que sa propre
-- marque "vu", jamais celle des autres.
create policy "lire ses propres vues"
  on public.instant_vues for select
  to authenticated
  using (profil_id = auth.uid());

create policy "marquer un instant vu si on peut le voir"
  on public.instant_vues for insert
  to authenticated
  with check (
    profil_id = auth.uid()
    and exists (
      select 1 from public.instants i
      where i.id = instant_id
        and (i.owner_user_id = auth.uid() or public.peut_voir_souvenir(i.parent_experience_id))
    )
  );


-- ============================================================
--  Storage — bucket dédié `instants` (règle 41, 69)
-- ============================================================
--  Bucket séparé de `souvenirs` plutôt que réutilisé : cycle de vie
--  différent (expiration sociale à 24h vs conservation permanente) et
--  types de média différents (photo + courte vidéo). Même politique de
--  chemin que `souvenirs` : {owner_id}/{fichier}.
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'instants', 'instants', false, 20971520,
  array['image/jpeg', 'image/png', 'video/mp4', 'video/quicktime']
)
on conflict (id) do nothing;

create policy "deposer son propre instant"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'instants'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "voir les medias instants des experiences visibles"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'instants'
    and exists (
      select 1 from public.instants i
      where i.media_url = storage.objects.name
        and (i.owner_user_id = auth.uid() or public.peut_voir_souvenir(i.parent_experience_id))
    )
  );

create policy "supprimer son propre media instant"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'instants'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
