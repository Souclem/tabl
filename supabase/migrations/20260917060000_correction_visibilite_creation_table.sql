-- ============================================================
--  Correction — création d'une Table invisible à l'instant même
--  où elle est créée (bug réel découvert en créant une Table pour
--  de vrai dans l'app, jamais visible dans flutter test)
-- ============================================================
--  `TableServiceSupabase.creer()` fait :
--    1. insert dans `tables` (avec RETURNING id, via .select().single())
--    2. insert dans `membres_table` (bootstrap : le créateur = admin actif)
--  La policy de lecture de `tables` ne reconnaît que "membre de la
--  Table" (`est_membre_table`) — au moment précis de l'étape 1, cette
--  ligne `membres_table` n'existe pas encore (elle n'est créée qu'à
--  l'étape 2). PostgREST ne peut donc pas relire la ligne qu'il vient
--  d'insérer pour la renvoyer, et remonte cet échec comme une
--  violation de policy RLS.
--
--  Correction : le créateur d'une Table doit de toute façon toujours
--  pouvoir la voir, indépendamment de son statut de membre à un
--  instant donné — même principe déjà appliqué à `souvenirs`
--  (`peut_voir_souvenir` : "l'auteur, toujours") et à `restaurants`
--  (lecture ouverte). Ça résout le problème par construction : au
--  moment de l'insert, `cree_par = auth.uid()` est vrai immédiatement,
--  sans dépendre d'une deuxième ligne pas encore écrite.
-- ============================================================

drop policy "lire les tables dont on est membre" on public.tables;
create policy "lire les tables dont on est membre"
  on public.tables for select
  to authenticated
  using (public.est_membre_table(id) or cree_par = auth.uid());
