-- ============================================================
--  Notifications du téléphone : les droits de la fonction `notifier`
-- ============================================================
--  Constat du 2026-11-01 (premiers tests TestFlight) : la cloche
--  marche, mais rien n'arrive sur l'iPhone. Tout était en place (clé
--  APNs, secrets, fonction déployée, appareil enregistré) sauf les
--  droits : les tables ne sont exposées à aucun rôle d'office, pas même
--  au rôle service des fonctions Edge (voir
--  20261020030000_retours_pseudo_auteur.sql). La fonction échouait donc
--  dès la relecture de l'action (« permission denied »), avant tout
--  envoi.
--
--  Ici, exactement ce qu'elle lit et écrit, colonne par colonne.
-- ============================================================

-- Relire l'action, pour savoir qui prévenir et quoi lui dire.
grant select (suiveur_id, suivi_id, statut, cree_le, accepte_le)
  on public.abonnements to service_role;
grant select (souvenir_id, profil_id, cree_le)
  on public.reactions to service_role;
grant select (id, souvenir_id, auteur_id, texte, cree_le)
  on public.commentaires to service_role;
grant select (
  id, demandeur_id, destinataire_id, restaurant_id, message, reponse, mot,
  cree_le, repondu_le
) on public.demandes_avis to service_role;
-- Le moment et son restaurant (« … a aimé votre moment chez Bibo »).
-- `souvenirs (id, auteur_id)` et `restaurants (id)` sont déjà accordés
-- (20261027060000_supprimer_un_compte.sql).
grant select (restaurant_id) on public.souvenirs to service_role;
grant select (nom) on public.restaurants to service_role;

-- Les téléphones du destinataire : les lire, retenir leur
-- environnement APNs, oublier ceux qui ne valent plus.
grant select (jeton, profil_id, environnement), delete
  on public.appareils to service_role;
grant update (environnement) on public.appareils to service_role;

-- Ce qui est déjà parti : une action ne notifie qu'une fois.
grant insert on public.notifications_envoyees to service_role;
