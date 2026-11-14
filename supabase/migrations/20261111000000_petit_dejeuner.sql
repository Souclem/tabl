-- ============================================================
--  « Petit-déjeuner » : le moment du repas peut valoir 'matin'
-- ============================================================
--  La feuille « Où et quand » propose Petit-déjeuner, Déjeuner et
--  Dîner ; `souvenirs.moment` n'acceptait que 'midi' et 'soir'.
--  Les apps déjà installées ignorent 'matin' (aucun libellé), sans
--  erreur.
--
--  Les notes écrites de « Ce qui ressort » (un plat noté, cinq au
--  plus) vivent dans `souvenirs.notes` sous la clé "plats" :
--  {"cuisine": 4, "plats": [{"nom": "Risotto", "note": 5}]}. La
--  contrainte existante (un objet) suffit : rien à changer ici.
-- ============================================================

alter table public.souvenirs
  drop constraint if exists souvenirs_moment_check;

alter table public.souvenirs
  add constraint souvenirs_moment_check
    check (moment in ('matin', 'midi', 'soir'));
