-- ============================================================
--  Un souvenir a toujours une photo ; supprimer ses photos
-- ============================================================
--  1. « Souvenir sans photo n'existe pas » (décision du 2026-10-26) : un
--     repas passé ajouté après coup part toujours d'au moins une photo,
--     la principale (`photo_url`). Les publications du Feed ne sont pas
--     concernées.
--  2. Supprimer un souvenir ou une publication efface aussi ses photos
--     du bucket : l'auteur peut supprimer les fichiers de son propre
--     dossier, comme pour les Instants et la photo de profil. Les
--     lignes liées (réactions, commentaires, photos 2 à 10, Instants…)
--     partent déjà avec le souvenir (`on delete cascade`).
-- ============================================================

alter table public.souvenirs
  add constraint souvenir_avec_photo
  check (not est_souvenir or photo_url is not null);

create policy "supprimer ses propres photos de souvenirs"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'souvenirs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
