-- ============================================================
--  Les photos déjà importées dans un souvenir
-- ============================================================
--  « Ajouter plusieurs de manière intelligente » ignore les photos déjà
--  rangées dans un souvenir. Chacune est reconnue par une empreinte
--  calculée sur le téléphone à partir de ses métadonnées d'origine
--  (instant, appareil, taille, position) — jamais de l'image —, gardée
--  ici avec le souvenir. Supprimer le souvenir libère ses photos
--  (`on delete cascade`) : elles peuvent être importées à nouveau.
--  Personne d'autre que l'auteur ne lit ces empreintes.
-- ============================================================

create table public.souvenirs_empreintes (
  souvenir_id uuid not null references public.souvenirs (id) on delete cascade,
  empreinte text not null,
  primary key (souvenir_id, empreinte)
);

grant select, insert on public.souvenirs_empreintes to authenticated;

alter table public.souvenirs_empreintes enable row level security;

create policy "lire les empreintes de ses souvenirs"
  on public.souvenirs_empreintes for select
  to authenticated
  using (
    exists (
      select 1 from public.souvenirs s
      where s.id = souvenir_id and s.auteur_id = auth.uid()
    )
  );

create policy "garder les empreintes de ses souvenirs"
  on public.souvenirs_empreintes for insert
  to authenticated
  with check (
    exists (
      select 1 from public.souvenirs s
      where s.id = souvenir_id and s.auteur_id = auth.uid()
    )
  );
