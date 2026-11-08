-- ============================================================
--  Étoiles facultatives d'un moment : `souvenirs.notes`
-- ============================================================
--  Le parcours de création (TAB-41) propose cinq catégories d'étoiles
--  facultatives, de 0 à 5 : cuisine, ambiance, service, lieu,
--  qualité-prix. Exemple : {"cuisine": 4, "ambiance": 3}. Une
--  catégorie non notée est absente de l'objet ; aucune note du tout =
--  NULL.
--
--  Pourquoi pas `impressions` : la fiche d'un restaurant agrège
--  `impressions` par libellé (« Ce qui ressort »). Les étoiles ne sont
--  jamais moyennées ni montrées sur la fiche du restaurant : elles
--  restent sur le moment, pour son auteur et ceux qui le voient.
--
--  Aucun droit à ajouter : `souvenirs` a déjà `grant select, insert,
--  update, delete` au niveau de la table pour `authenticated`, et les
--  policies (auteur pour écrire, `peut_voir_souvenir()` pour lire)
--  s'appliquent à la ligne entière, donc à cette colonne aussi.
--  `service_role` n'a que des grants par colonne sur `souvenirs` : il
--  ne voit pas `notes`, ce qui est voulu.
-- ============================================================

alter table public.souvenirs
  add column notes jsonb,
  add constraint souvenirs_notes_objet
    check (notes is null or jsonb_typeof(notes) = 'object');
