import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Tente une connexion Apple/Google, avec la gestion d'erreur uniforme
/// déjà répétée telle quelle dans `EcranAccueil`, `EcranConnexion` et
/// `EcranInscription`.
///
/// Renvoie `null` si l'utilisateur annule ou si une erreur survient (déjà
/// signalée via [afficherMessage]) — l'appelant n'a plus qu'à réagir à un
/// résultat non nul, la navigation qui suit reste spécifique à chaque
/// écran (elle diffère selon qu'on est sur "Se connecter" ou "Créer un
/// compte").
Future<ResultatConnexionOAuth?> tenterConnexionOAuth(
  BuildContext context,
  Future<ResultatConnexionOAuth?> Function() connexion,
) async {
  try {
    return await connexion();
  } on ErreurAuth catch (e) {
    if (context.mounted) afficherMessage(context, e.message);
    return null;
  } catch (_) {
    if (context.mounted) afficherMessage(context, messageErreurGenerique);
    return null;
  }
}
