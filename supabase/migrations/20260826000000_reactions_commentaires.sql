-- ============================================================
--  reactions — "j'aime" sur un souvenir
-- ============================================================
--  Une ligne = une personne a réagi à un souvenir. Pas de colonne type
--  de réaction pour l'instant : un seul geste ("j'aime"), pas plusieurs
--  émotions à choisir — inutile d'anticiper une variété qui n'existe pas
--  encore côté produit.
-- ============================================================

create table public.reactions (
  souvenir_id uuid not null references public.souvenirs (id) on delete cascade,
  profil_id uuid not null references public.profils (id) on delete cascade,
  cree_le timestamptz not null default now(),
  primary key (souvenir_id, profil_id)
);

grant select, insert, delete on public.reactions to authenticated;

alter table public.reactions enable row level security;

-- Lecture/écriture toutes gardées par la visibilité du souvenir
-- lui-même : pas besoin de redupliquer la logique d'abonnement-accepté,
-- la policy SELECT de `souvenirs` s'applique déjà en transparence à
-- cette sous-requête (souvenir invisible pour l'appelant → EXISTS faux).
create policy "lire les reactions des souvenirs visibles"
  on public.reactions for select
  to authenticated
  using (
    exists (select 1 from public.souvenirs s where s.id = reactions.souvenir_id)
  );

create policy "reagir a un souvenir visible"
  on public.reactions for insert
  to authenticated
  with check (
    profil_id = auth.uid()
    and exists (select 1 from public.souvenirs s where s.id = souvenir_id)
  );

create policy "retirer sa reaction"
  on public.reactions for delete
  to authenticated
  using (profil_id = auth.uid());


-- ============================================================
--  commentaires
-- ============================================================
--  Pas d'édition (pas de policy update) : on commente, on peut retirer
--  son propre commentaire, on ne le corrige pas après coup — plus simple
--  à raisonner, cohérent avec le reste du projet.
-- ============================================================

create table public.commentaires (
  id uuid primary key default gen_random_uuid(),
  souvenir_id uuid not null references public.souvenirs (id) on delete cascade,
  auteur_id uuid not null references public.profils (id) on delete cascade,
  texte text not null check (char_length(texte) between 1 and 500),
  cree_le timestamptz not null default now()
);

grant select, insert, delete on public.commentaires to authenticated;

alter table public.commentaires enable row level security;

create policy "lire les commentaires des souvenirs visibles"
  on public.commentaires for select
  to authenticated
  using (
    exists (select 1 from public.souvenirs s where s.id = commentaires.souvenir_id)
  );

create policy "commenter un souvenir visible"
  on public.commentaires for insert
  to authenticated
  with check (
    auteur_id = auth.uid()
    and exists (select 1 from public.souvenirs s where s.id = souvenir_id)
  );

create policy "supprimer son commentaire"
  on public.commentaires for delete
  to authenticated
  using (auteur_id = auth.uid());
