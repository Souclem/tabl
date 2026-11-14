import 'package:supabase_flutter/supabase_flutter.dart';

import '../avis/avis.dart';
import '../social/photo_profil.dart';
import '../stockage/liens_signes.dart';
import 'notification.dart';
import 'notification_service.dart';

/// Adossé à `mes_notifications()` et à `profils.notifications_vues_le`
/// (migration `20261027010000_notifications.sql`).
class NotificationServiceSupabase implements NotificationService {
  NotificationServiceSupabase(this._client);

  final SupabaseClient _client;

  String get _monId => _client.auth.currentSession!.user.id;

  @override
  Future<({List<NotificationTabl> notifications, DateTime? vuesLe})>
  mesNotifications() async {
    final (lignes, profil) = await (
      _client.rpc<List<dynamic>>('mes_notifications'),
      _client
          .from('profils')
          .select('notifications_vues_le')
          .eq('id', _monId)
          .single(),
    ).wait;
    final brutes = lignes.cast<Map<String, dynamic>>();
    final photos = await liensSignes(_client, 'souvenirs', {
      for (final l in brutes) ?l['souvenir_photo'] as String?,
    });
    final vuesLe = profil['notifications_vues_le'] as String?;
    return (
      notifications: [
        for (final l in brutes)
          if (TypeNotification.depuisValeur(l['type'] as String?)
              case final type?)
            NotificationTabl(
              type: type,
              acteur: (
                id: l['acteur_id'] as String,
                pseudo: l['acteur_pseudo'] as String? ?? '',
                photoUrl: urlPhotoProfil(
                  _client,
                  l['acteur_photo'] as String?,
                  miniature: true,
                ),
              ),
              creeLe: DateTime.parse(l['cree_le'] as String).toLocal(),
              souvenirId: l['souvenir_id'] as String?,
              souvenirPhotoUrl: photos[l['souvenir_photo']],
              restaurantId: l['restaurant_id'] as String?,
              restaurantNom: l['restaurant_nom'] as String?,
              restaurantGenre: l['restaurant_genre'] as String?,
              texte: l['texte'] as String?,
              reponse: ReponseAvis.depuisValeur(l['reponse'] as String?),
              demandeId: l['demande_id'] as String?,
              commentaireId: l['commentaire_id'] as String?,
            ),
      ],
      vuesLe: vuesLe == null ? null : DateTime.parse(vuesLe).toLocal(),
    );
  }

  @override
  Future<void> marquerVues(DateTime moment) async {
    await _client
        .from('profils')
        .update({'notifications_vues_le': moment.toUtc().toIso8601String()})
        .eq('id', _monId);
  }
}
