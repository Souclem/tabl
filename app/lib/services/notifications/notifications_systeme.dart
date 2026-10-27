import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Les notifications du téléphone, sur l'écran verrouillé : l'autorisation,
/// cet appareil enregistré pour le compte connecté, et les notifications
/// touchées. L'envoi vit côté serveur (fonction `notifier`, voir
/// [prevenir]).
abstract interface class NotificationsSysteme {
  /// Demande l'autorisation (iOS ne la demande qu'une fois, puis s'en
  /// souvient) et enregistre cet appareil pour le compte connecté.
  Future<void> activer();

  /// Le type d'une notification touchée (« demande_suivi »…).
  Stream<String> get touchees;
}

/// Sur iPhone, par le canal `tabl/notifications` (`AppDelegate.swift`) ;
/// ailleurs, rien pour l'instant.
class NotificationsSystemeSupabase implements NotificationsSysteme {
  NotificationsSystemeSupabase(this._client) {
    _canal.setMethodCallHandler(_recevoir);
  }

  static const _canal = MethodChannel('tabl/notifications');

  final SupabaseClient _client;
  final _touchees = StreamController<String>.broadcast();

  @override
  Stream<String> get touchees => _touchees.stream;

  @override
  Future<void> activer() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      await _canal.invokeMethod<bool>('activer');
      // Dart écoute : une notification touchée pour ouvrir l'app arrive
      // maintenant.
      await _canal.invokeMethod<void>('pret');
    } on PlatformException catch (e) {
      debugPrint('NotificationsSysteme: activer : $e');
    }
  }

  Future<void> _recevoir(MethodCall appel) async {
    switch (appel.method) {
      case 'jeton':
        final jeton = appel.arguments as String;
        try {
          await _client.rpc(
            'enregistrer_appareil',
            params: {'p_jeton': jeton, 'p_plateforme': 'ios'},
          );
          final preferences = await SharedPreferences.getInstance();
          await preferences.setString(_cleJeton, jeton);
        } catch (e) {
          debugPrint('NotificationsSysteme: enregistrer : $e');
        }
      case 'touchee':
        final donnees = Map<Object?, Object?>.from(appel.arguments as Map);
        _touchees.add(donnees['type'] as String? ?? '');
      case 'erreur':
        // Typiquement : l'app n'a pas le droit aux notifications (signée
        // sans le compte Apple Developer).
        debugPrint('NotificationsSysteme: ${appel.arguments}');
    }
  }
}

const _cleJeton = 'notifications_jeton_appareil';

/// Retire cet appareil du compte connecté, juste avant la déconnexion :
/// ses notifications ne suivent ni le compte parti, ni le suivant avant
/// qu'il ne l'enregistre.
Future<void> oublierCetAppareil(SupabaseClient client) async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final jeton = preferences.getString(_cleJeton);
    if (jeton == null) return;
    await client.from('appareils').delete().eq('jeton', jeton);
    await preferences.remove(_cleJeton);
  } catch (e) {
    debugPrint('NotificationsSysteme: oublier : $e');
  }
}

/// Prévient la fonction `notifier` qu'une action vient d'avoir lieu, sans
/// faire attendre : elle la relit en base et notifie qui de droit sur son
/// téléphone. Une notification qui ne part pas ne bloque rien — l'action
/// est déjà faite, et la cloche la montrera.
void prevenir(SupabaseClient client, Map<String, Object?> evenement) {
  unawaited(
    client.functions
        .invoke('notifier', body: evenement)
        .then<void>((_) {}, onError: (Object e) => debugPrint('notifier : $e')),
  );
}
