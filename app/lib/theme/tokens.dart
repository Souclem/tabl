import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Les valeurs brutes du design de Tabl.
///
/// C'est jE fichier à modifier pour changer l'allure de l'application.
/// Aucune couleur, aucune taille et aucun espacement ne doit être écrit
/// "en dur" ailleurs : tout passe par ici. Changer une valeur ci-dessous
/// la répercute partout d'un coup.
class TablTokens {
  const TablTokens._();

  // --- Couleurs -------------------------------------------------------
  // Thème sombre, accent doré — valeurs exactes reprises du prototype
  // fonctionnel `instruction/Clément (2)/Tabl.dc.html` (source de vérité
  // pour l'écran Feed), pas d'une approximation à l'œil.

  /// Couleur d'accent : boutons principaux, liens, éléments actifs.
  static const Color primaire = Color(0xFFD9AC67);

  /// Variante foncée, pour les états pressés.
  static const Color primaireFoncee = Color(0xFFA8804A);

  /// Fond des écrans.
  static const Color fond = Color(0xFF06080C);

  /// Fond des cartes, des champs et des surfaces posées sur le fond.
  static const Color surface = Color(0xFF221C17);

  /// Cartes posées à même le fond, plus discrètes que [surface] (profil :
  /// bilan, sélecteurs).
  static const Color surfaceBasse = Color(0xFF110F0C);

  /// Texte principal.
  static const Color texte = Color(0xFFF5F0E8);

  /// Texte secondaire : légendes, aides de saisie.
  static const Color texteDoux = Color(0xFF9C9284);

  /// Texte posé sur la couleur primaire (fond doré → texte foncé pour le contraste).
  static const Color texteSurPrimaire = Color(0xFF05090F);

  /// Traits de séparation et contours de champs au repos.
  static const Color bordure = Color(0xFF3A322A);

  /// Erreurs de saisie.
  static const Color erreur = Color(0xFFE0685C);

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

  /// Boutons en pilule (radius 999 — voir la bible de design,
  /// `instruction/Clément (2)/uploads/Tabl_Design_Bible_Complete.docx`,
  /// section "Border Radius" : "Boutons : 999 px").
  static const double arrondiBouton = 999;

  // --- Dimensions -----------------------------------------------------
  /// Hauteur des champs de saisie et des boutons. 48 est le minimum
  /// confortable pour un doigt sur mobile.
  static const double hauteurControle = 52;

  /// Largeur maximale d'un formulaire, pour qu'il ne s'étire pas
  /// bêtement sur une tablette.
  static const double largeurMaxFormulaire = 420;

  // --- Typographie ----------------------------------------------------
  static const String police = 'Roboto';

  /// Police d'affichage (titres éditoriaux) — "Playfair Display",
  /// exactement celle du prototype fonctionnel
  /// (`instruction/Clément (2)/Tabl.dc.html`, ex. le nom d'un restaurant
  /// dans le Feed, "Tabl." en en-tête). Un getter, pas un `const`, car
  /// `google_fonts` construit le `TextStyle` à l'exécution.
  static TextStyle get titreAffichage => GoogleFonts.playfairDisplay(
    color: texte,
    fontWeight: FontWeight.w500,
  );

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

  /// Style du wordmark "tabl." affiché en haut des écrans d'authentification
  /// et de présentation.
  static const TextStyle logo = TextStyle(
    fontFamily: police,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: primaire,
    letterSpacing: 0.2,
  );

  // --- Indicateur de page -----------------------------------------------
  static const double tailleIndicateurPage = 6;
  static const double tailleIndicateurPageActif = 20;
}
