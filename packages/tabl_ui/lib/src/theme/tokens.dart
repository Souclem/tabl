import 'package:flutter/material.dart';

/// Les valeurs brutes du design de Tabl.
///
/// C'est LE fichier à modifier pour changer l'allure de l'application.
/// Aucune couleur, aucune taille et aucun espacement ne doit être écrit
/// "en dur" ailleurs : tout passe par ici. Changer une valeur ci-dessous
/// la répercute partout d'un coup.
class TablTokens {
  const TablTokens._();

  // --- Couleurs -------------------------------------------------------
  /// Couleur d'accent : boutons principaux, liens, éléments actifs.
  static const Color primaire = Color(0xFFC65A3A);

  /// Variante foncée, pour les états pressés.
  static const Color primaireFoncee = Color(0xFFA84829);

  /// Fond des écrans.
  static const Color fond = Color(0xFFFDFAF7);

  /// Fond des cartes, des champs et des surfaces posées sur le fond.
  static const Color surface = Color(0xFFFFFFFF);

  /// Texte principal.
  static const Color texte = Color(0xFF2A2422);

  /// Texte secondaire : légendes, aides de saisie.
  static const Color texteDoux = Color(0xFF7D726C);

  /// Texte posé sur la couleur primaire.
  static const Color texteSurPrimaire = Color(0xFFFFFFFF);

  /// Traits de séparation et contours de champs au repos.
  static const Color bordure = Color(0xFFE9E0D9);

  /// Erreurs de saisie.
  static const Color erreur = Color(0xFFC0392B);

  // --- Espacements ----------------------------------------------------
  // Une échelle, pas des nombres au hasard : tout est un multiple de 4.
  static const double espaceXs = 4;
  static const double espaceS = 8;
  static const double espaceM = 16;
  static const double espaceL = 24;
  static const double espaceXl = 32;
  static const double espaceXxl = 48;

  // --- Arrondis -------------------------------------------------------
  static const double arrondiS = 8;
  static const double arrondiM = 16;
  static const double arrondiL = 24;

  // --- Dimensions -----------------------------------------------------
  /// Hauteur des champs de saisie et des boutons. 48 est le minimum
  /// confortable pour un doigt sur mobile.
  static const double hauteurControle = 52;

  /// Largeur maximale d'un formulaire, pour qu'il ne s'étire pas
  /// bêtement sur une tablette.
  static const double largeurMaxFormulaire = 420;

  // --- Typographie ----------------------------------------------------
  static const String police = 'Roboto';

  static const TextStyle grandTitre = TextStyle(
    fontFamily: police,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: texte,
    height: 1.15,
    letterSpacing: -0.5,
  );

  static const TextStyle titre = TextStyle(
    fontFamily: police,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: texte,
    height: 1.25,
  );

  static const TextStyle sousTitre = TextStyle(
    fontFamily: police,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: texte,
    height: 1.3,
  );

  static const TextStyle corps = TextStyle(
    fontFamily: police,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: texte,
    height: 1.45,
  );

  static const TextStyle legende = TextStyle(
    fontFamily: police,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: texteDoux,
    height: 1.3,
  );

  static const TextStyle libelleBouton = TextStyle(
    fontFamily: police,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
}
