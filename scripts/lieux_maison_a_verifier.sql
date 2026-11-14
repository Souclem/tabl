-- Lieux saisis à la main dont le nom ressemble à une maison, encore
-- publics (donc sur la carte s'ils ont une position). Lecture seule : à
-- coller dans l'éditeur SQL de Supabase par le propriétaire du projet.
-- La migration 20261114010000_chez_moi_sans_position.sql a déjà corrigé
-- les noms exacts (« chez moi », « maison »…) ; ceux-ci sont à juger un
-- par un (« Chez Léon » peut être un vrai restaurant).

select r.id,
       r.nom,
       r.ville,
       r.latitude is not null as sur_la_carte,
       p.pseudo as cree_par,
       (select count(*) from public.souvenirs s where s.restaurant_id = r.id)
         as moments,
       (select count(distinct s.auteur_id) from public.souvenirs s
         where s.restaurant_id = r.id) as auteurs,
       r.cree_le
from public.restaurants r
left join public.profils p on p.id = r.cree_par
where not r.prive
  and r.fsq_place_id is null
  and lower(r.nom) ~ '(^|\s)(chez|maison|home|appart|appartement|domicile|parents|mamie|papy|famille|coloc|kot)(\s|$)'
order by r.latitude is not null desc, r.cree_le desc;
