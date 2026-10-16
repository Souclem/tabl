-- ============================================================
--  Correction — visibilité des photos dupliquée 3 fois sur Storage
--  (megaprompt Bloc 5, règles 92/94 : "ne pas copier la logique
--  différente dans chaque écran" — trouvé en audit)
-- ============================================================
--  Deux policies séparées géraient chacune un chemin de visibilité
--  différent pour le même bucket `souvenirs` : "voir les photos de
--  son cercle" (cercle direct) et "voir les photos des experiences
--  partagees dans mes tables" (association Table) — alors que
--  `peut_voir_souvenir()` couvre déjà les deux cas depuis le Bloc 5.
--  Une seule policy, appuyée sur cette même fonction, les remplace.
--
--  Bonus : la policy Table ne couvrait que `photo_url`, jamais
--  `boisson_photo_url` — la nouvelle policy couvre les deux colonnes.
--  Le repli "propre dossier" est conservé : au moment précis de
--  l'upload, avant que la ligne `souvenirs` existe (le flux publie
--  d'abord la photo, insère la ligne ensuite), l'auteur doit pouvoir
--  relire son propre fichier sans dépendre d'une ligne pas encore
--  écrite.
-- ============================================================

drop policy "voir les photos de son cercle" on storage.objects;
drop policy "voir les photos des experiences partagees dans mes tables" on storage.objects;

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
    )
  );
