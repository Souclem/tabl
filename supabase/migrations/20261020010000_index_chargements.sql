-- ============================================================
--  Index des chargements courants : profil, Feed, commentaires
-- ============================================================
--  Postgres n'indexe pas de lui-même les colonnes de clé étrangère :
--  ces recherches parcouraient la table entière, et chaque ligne
--  parcourue passait par la règle de visibilité (`peut_voir_souvenir`).
--  Rien ne change dans ce qui est visible, seulement la vitesse.
-- ============================================================

-- Les commentaires d'un moment, dans l'ordre, et leur nombre (Feed,
-- profil, moment agrandi).
create index if not exists commentaires_souvenir
  on public.commentaires (souvenir_id, cree_le);

-- Les moments publiés d'un profil, du plus récent au plus ancien : la
-- base lit les 50 premiers dans l'ordre au lieu de tout trier.
create index if not exists souvenirs_auteur_publies_recents
  on public.souvenirs (auteur_id, date_visite desc, cree_le desc)
  where statut = 'publie';

-- Le Feed, même principe sur tout le réseau : la base s'arrête dès
-- qu'elle a trouvé 50 moments visibles, au lieu de vérifier la
-- visibilité de tous avant de trier.
create index if not exists souvenirs_publies_recents
  on public.souvenirs (date_visite desc, cree_le desc)
  where statut = 'publie';

-- Les abonnés d'un profil (listes, compteurs) : la clé primaire
-- (suiveur_id, suivi_id) ne sert que dans l'autre sens, ceux qu'on suit.
create index if not exists abonnements_suivi
  on public.abonnements (suivi_id, statut);

-- Les Tables dont on est membre : la contrainte unique
-- (table_id, profil_id) ne sert que depuis une Table.
create index if not exists membres_table_profil
  on public.membres_table (profil_id, statut);

-- Les instants d'un moment (signal sur les publications du Feed).
create index if not exists instants_moment
  on public.instants (parent_experience_id);
