-- ============================================================
--  Accepter une demande de suivi : de nouveau possible
-- ============================================================
--  `20261027010000_notifications.sql` a ajouté `abonnements.accepte_le`
--  (posé par l'app en acceptant, pour « Clara a accepté votre
--  demande ») sans le droit de l'écrire : depuis
--  `20260825000000_corrections_revue.sql`, seul `statut` est
--  modifiable. Accepter une demande, ou repasser son profil en public,
--  échouait donc avec « permission denied ».
--
--  On ouvre cette seule colonne. La policy « accepter une demande »
--  continue de réserver la modification au suivi ; `suiveur_id` et
--  `suivi_id` restent immuables.
-- ============================================================

grant update (accepte_le) on public.abonnements to authenticated;
