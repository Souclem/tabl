-- ============================================================
--  Les « chez moi » déjà publiés : plus de position
-- ============================================================
--  Avant le 2026-11-14, un « restaurant » saisi à la main recevait la
--  position du téléphone quand les photos n'en avaient pas. Mangé chez
--  soi, nommé « chez moi », il plaçait le domicile sur la carte de tous
--  les abonnés. L'app ne le fait plus (lieux_chez) ; ici, les lignes
--  déjà en base deviennent des lieux personnels « Chez moi » : sans
--  adresse, ni position, ni ville, ni quartier.
--
--  Seulement les cas sûrs, pour ne jamais toucher un vrai restaurant :
--  - saisi à la main (aucun identifiant d'annuaire), par quelqu'un ;
--  - nommé exactement « chez moi », « chez nous », « à la maison »,
--    « maison », « home » ou « domicile » (un vrai restaurant
--    « Chez Léon » n'est pas concerné) ;
--  - personne d'autre que son auteur ne s'en sert (moment, sauvegarde,
--    proposition à une Table, demande d'avis).
--  Les autres noms qui ressemblent à une maison se vérifient à la main :
--  scripts/lieux_maison_a_verifier.sql (lecture seule).
--
--  Rejouable sans effet : une ligne déjà corrigée est privée.
-- ============================================================

update public.restaurants r
set prive = true,
    genre = 'domicile',
    nom = 'Chez moi',
    nom_recherche = 'chez moi',
    ville = '',
    quartier = null,
    adresse = null,
    latitude = null,
    longitude = null
where not r.prive
  and r.fsq_place_id is null
  and r.cree_par is not null
  and lower(btrim(r.nom)) in (
    'chez moi', 'chez nous', 'à la maison', 'a la maison', 'maison',
    'home', 'domicile'
  )
  and not exists (
    select 1 from public.souvenirs s
    where s.restaurant_id = r.id and s.auteur_id is distinct from r.cree_par
  )
  and not exists (
    select 1 from public.restaurants_sauvegardes rs
    where rs.restaurant_id = r.id and rs.profil_id is distinct from r.cree_par
  )
  and not exists (
    select 1 from public.table_propositions tp where tp.restaurant_id = r.id
  )
  and not exists (
    select 1 from public.demandes_avis d where d.restaurant_id = r.id
  );
