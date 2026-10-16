-- ============================================================
--  Correction — publier un souvenir échoue systématiquement
--  (bug réel, critique, découvert en publiant pour de vrai dans
--  l'app — cassait TOUTE publication, pas seulement avec une Table)
-- ============================================================
--  Depuis `20260917030000_visibilite_experience_centralisee.sql`, la
--  policy de lecture de `souvenirs` délègue entièrement à
--  `peut_voir_souvenir(id)`, une fonction SECURITY DEFINER. Or
--  `SouvenirServiceSupabase.publier()` fait `insert(...).select('id')`
--  (RETURNING) pour récupérer l'id créé.
--
--  Constaté empiriquement (`supabase db query`, session simulée) :
--  - Un SELECT séparé, dans la même transaction, juste après l'insert,
--    voit très bien la ligne via `peut_voir_souvenir()` (retourne true).
--  - Mais le RETURNING de l'INSERT lui-même échoue avec "new row
--    violates row-level security policy" — la fonction SECURITY
--    DEFINER, exécutée à l'intérieur du RETURNING de ce même insert,
--    ne "voit" pas la ligne qu'il vient de créer (probablement un
--    effet de bord du changement de contexte d'exécution SECURITY
--    DEFINER sur le RETURNING d'un INSERT — un plain SELECT séparé
--    n'a pas ce problème).
--
--  C'est exactement la même famille de correction que
--  `20260917060000_correction_visibilite_creation_table.sql` pour
--  `tables` : ajouter une clause directe sur les colonnes de la
--  nouvelle ligne (pas de sous-requête, pas de fonction) permet à
--  Postgres de l'évaluer immédiatement contre la ligne en cours
--  d'insertion, sans passer par ce chemin défaillant. L'auteur d'un
--  souvenir doit de toute façon toujours pouvoir le voir — exactement
--  la règle "l'auteur, toujours" déjà au cœur de `peut_voir_souvenir`
--  elle-même, simplement dupliquée ici en clause rapide.
-- ============================================================

drop policy "lire les souvenirs de son cercle" on public.souvenirs;
create policy "lire les souvenirs de son cercle"
  on public.souvenirs for select
  to authenticated
  using (auteur_id = auth.uid() or public.peut_voir_souvenir(id));
