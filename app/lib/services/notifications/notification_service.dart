import 'notification.dart';

/// Mes notifications : ce qui arrive à mes souvenirs (j'aime,
/// commentaires) et à mes abonnements (demandes, suivis acceptés).
abstract interface class NotificationService {
  /// Les plus récentes d'abord, et jusqu'où je les ai déjà vues.
  Future<({List<NotificationTabl> notifications, DateTime? vuesLe})>
  mesNotifications();

  /// Tout ce qui est arrivé jusqu'à [moment] est vu : la pastille de la
  /// cloche s'éteint.
  Future<void> marquerVues(DateTime moment);
}
