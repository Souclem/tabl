-- ============================================================
--  Aide et contact : la fonction `transmettre-retours` lit le pseudo
--  de l'auteur
-- ============================================================
--  Les tables ne sont exposées à aucun rôle d'office, pas même au rôle
--  service des fonctions Edge : sans ce droit, recopier un message
--  dans la feuille de l'équipe échouait (permission refusée sur
--  `profils`). Seulement l'identifiant et le pseudo, rien d'autre.
-- ============================================================

grant select (id, pseudo) on public.profils to service_role;
