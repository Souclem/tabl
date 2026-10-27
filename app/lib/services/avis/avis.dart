import 'package:supabase_flutter/supabase_flutter.dart';

import '../notifications/notifications_systeme.dart';

/// La réponse d'un proche à « Tu me conseilles d'y aller ? », en un
/// toucher.
enum ReponseAvis {
  oui('oui', '😍', 'Oui, vas-y'),
  depend('depend', '🤔', 'Ça dépend'),
  non('non', '😕', 'Je ne conseille pas');

  const ReponseAvis(this.valeur, this.emoji, this.libelle);

  /// La valeur de `demandes_avis.reponse`.
  final String valeur;
  final String emoji;
  final String libelle;

  static ReponseAvis? depuisValeur(String? valeur) =>
      values.where((r) => r.valeur == valeur).firstOrNull;
}

/// « Tu me conseilles d'aller chez Septime ? » : la question proposée,
/// qu'on peut changer avant d'envoyer.
String questionAvis(String restaurant) =>
    'Tu me conseilles d\'aller chez $restaurant ?';

/// Demander un avis à des proches qui sont allés dans un restaurant, et
/// répondre à ceux qu'on me demande. Toujours privé : rien n'est publié.
abstract interface class AvisService {
  /// Une demande par proche de [destinataireIds].
  Future<void> demander({
    required String restaurantId,
    required List<String> destinataireIds,
    required String message,
  });

  /// Ma réponse à une demande qu'on m'a faite, avec un mot si je veux.
  Future<void> repondre(String demandeId, ReponseAvis reponse, {String? mot});
}

/// Adossé à `demandes_avis` (migration `20261027020000_demander_un_avis.sql`).
class AvisServiceSupabase implements AvisService {
  AvisServiceSupabase(this._client);

  final SupabaseClient _client;

  String get _monId => _client.auth.currentSession!.user.id;

  @override
  Future<void> demander({
    required String restaurantId,
    required List<String> destinataireIds,
    required String message,
  }) async {
    if (destinataireIds.isEmpty) return;
    final demandes = await _client
        .from('demandes_avis')
        .insert([
          for (final id in destinataireIds.toSet())
            {
              'demandeur_id': _monId,
              'destinataire_id': id,
              'restaurant_id': restaurantId,
              'message': message.trim(),
            },
        ])
        .select('id');
    prevenir(_client, {
      'evenement': 'demande_avis',
      'demandes': [for (final d in demandes) d['id']],
    });
  }

  @override
  Future<void> repondre(
    String demandeId,
    ReponseAvis reponse, {
    String? mot,
  }) async {
    final texte = mot?.trim();
    await _client
        .from('demandes_avis')
        .update({
          'reponse': reponse.valeur,
          'mot': texte == null || texte.isEmpty ? null : texte,
          'repondu_le': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', demandeId);
    prevenir(_client, {'evenement': 'avis_recu', 'demande': demandeId});
  }
}
