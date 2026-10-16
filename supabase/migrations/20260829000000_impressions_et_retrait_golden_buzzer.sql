-- ============================================================
--  souvenirs — impressions ("Ce qui ressort"), retrait Golden Buzzer
-- ============================================================
--  Le prototype fonctionnel (Tabl.dc.html) montre que "Golden Buzzer"
--  est un statut de RESTAURANT (niveau golden/recommended/standard sur
--  Explorer/Carte), pas un marquage que l'auteur applique à son propre
--  moment — la colonne `golden_buzzer` ajoutée précédemment reposait sur
--  une mauvaise lecture du cahier des charges texte. On ne la supprime
--  pas (une colonne inutilisée est sans risque), mais l'app cesse de
--  l'utiliser côté moment. `impressions` est en revanche bien réelle
--  (tags "Assiette", "Service"... affichés sur chaque carte du Feed).
-- ============================================================

alter table public.souvenirs
  add column impressions text[] not null default '{}';
