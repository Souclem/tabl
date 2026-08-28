import 'package:flutter/material.dart';

/// Affiche un message furtif en bas de l'écran (erreur, confirmation...).
///
/// Centralisé ici pour que tous les écrans affichent leurs messages de la
/// même façon, sans redéfinir `ScaffoldMessenger.of(context).showSnackBar`
/// à chaque endroit.
void afficherMessage(BuildContext context, String texte) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
}

/// Message générique pour une erreur inattendue (réseau, serveur...) — pas
/// une erreur métier typée, qui porte déjà un message présentable.
/// Mieux vaut ça qu'un écran silencieusement figé sans aucun retour.
const String messageErreurGenerique = 'Une erreur est survenue. Réessaie.';
