-- ============================================================
--  Les anciens lieux personnels « chez moi » : genre domicile
-- ============================================================
--  Avant les genres (20261114000000_lieux_chez.sql), « Créer un lieu
--  personnel » servait aussi à dire « chez moi ». Ces lieux sont déjà
--  privés et sans position (rien ne fuit) ; mais sans genre, l'app les lit
--  comme « chez quelqu'un » : ils s'affichent « chez moi » chez tous les
--  lecteurs et en double à côté du « Chez moi » de la feuille « Où et
--  quand ». Rangés en « Chez moi » (genre domicile), ils se lisent « Chez
--  vous » pour leur auteur, « Chez <pseudo> » pour les autres.
--
--  Mêmes noms exacts que 20261114010000_chez_moi_sans_position.sql.
--  Rejouable sans effet.
-- ============================================================

update public.restaurants
set genre = 'domicile',
    nom = 'Chez moi',
    nom_recherche = 'chez moi'
where prive
  and genre is null
  and hote_id is null
  and lower(btrim(nom)) in (
    'chez moi', 'chez nous', 'à la maison', 'a la maison', 'maison',
    'home', 'domicile'
  );
