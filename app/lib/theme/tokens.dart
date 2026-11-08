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
  //
  // Ces constantes sont les couleurs du SOMBRE, rien d'autre. Un écran qui
  // doit suivre l'apparence (clair/sombre) lit ses couleurs par
  // `TablCouleurs.of(context)` (plus bas) ; les écrans pas encore migrés
  // continuent de les lire ici, donc restent sombres.

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

  // --- Feuille ivoire -------------------------------------------------
  // Les filtres et le tri de l'Explorer, sur papier clair (direction
  // « A · Carnet » de Martin, novembre 2026) : valeurs reprises de sa
  // maquette.

  /// Fond de la feuille et du menu de tri.
  static const Color papier = Color(0xFFFBF8F2);

  /// Fond des sélecteurs posés sur le papier.
  static const Color lin = Color(0xFFEFE8DB);

  /// Texte et éléments choisis, sur le papier.
  static const Color encre = Color(0xFF07111F);

  /// Texte secondaire sur le papier.
  static const Color encreDouce = Color(0xFF4F5562);

  /// Valeurs au repos, aides, chevrons.
  static const Color encrePale = Color(0xFF6B707C);

  /// Le point qui signale un filtre actif.
  static const Color pointActif = Color(0xFFC9963F);

  /// Interrupteur éteint.
  static const Color interrupteurEteint = Color(0xFFDCD3C3);

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
  static TextStyle get titreAffichage =>
      GoogleFonts.playfairDisplay(color: texte, fontWeight: FontWeight.w500);

  /// Les noms et les titres de l'Explorer : une grotesque très grasse et
  /// serrée (Bricolage Grotesque, maquette de Martin), embarquée dans
  /// l'app (`assets/polices`).
  static const TextStyle titreSerre = TextStyle(
    fontFamily: 'BricolageGrotesque',
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wght', 790), FontVariation('wdth', 76)],
    letterSpacing: -0.7,
    height: 1,
    color: texte,
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

/// Les couleurs de l'apparence en cours, clair ou sombre.
///
/// Posée dans le [ThemeData] de l'application (voir `TablTheme`) : un
/// écran ou un composant fait `final c = TablCouleurs.of(context)` puis
/// `c.fond`, `c.texte`, `c.corps`… et suit tout seul le réglage Apparence.
/// Pour changer une teinte du clair ou du sombre, c'est ici.
///
/// Le sombre reprend les [TablTokens] à l'identique ; le clair reprend la
/// palette de l'Explorer (fond de lin, braise, ivoire, encre). Hors thème
/// Tabl (tests avec un `MaterialApp` nu), on obtient le sombre.
@immutable
class TablCouleurs extends ThemeExtension<TablCouleurs> {
  const TablCouleurs({
    required this.primaire,
    required this.primaireFoncee,
    required this.fond,
    required this.surface,
    required this.surfaceBasse,
    required this.texte,
    required this.texteDoux,
    required this.texteSurPrimaire,
    required this.bordure,
    required this.erreur,
  });

  /// Accent : boutons principaux, liens, éléments actifs.
  final Color primaire;

  /// Variante foncée de l'accent, pour les états pressés.
  final Color primaireFoncee;

  /// Fond des écrans.
  final Color fond;

  /// Cartes, champs et feuilles posés sur le fond.
  final Color surface;

  /// Cartes posées à même le fond, plus discrètes que [surface].
  final Color surfaceBasse;

  final Color texte;

  /// Légendes, aides de saisie.
  final Color texteDoux;

  /// Texte posé sur [primaire].
  final Color texteSurPrimaire;

  /// Traits de séparation et contours au repos.
  final Color bordure;

  final Color erreur;

  static const sombre = TablCouleurs(
    primaire: TablTokens.primaire,
    primaireFoncee: TablTokens.primaireFoncee,
    fond: TablTokens.fond,
    surface: TablTokens.surface,
    surfaceBasse: TablTokens.surfaceBasse,
    texte: TablTokens.texte,
    texteDoux: TablTokens.texteDoux,
    texteSurPrimaire: TablTokens.texteSurPrimaire,
    bordure: TablTokens.bordure,
    erreur: TablTokens.erreur,
  );

  static const clair = TablCouleurs(
    // La braise de l'Explorer.
    primaire: Color(0xFFAF4A2C),
    primaireFoncee: Color(0xFF8C3A21),
    // Le fond de lin de l'Explorer, et l'ivoire des feuilles.
    fond: Color(0xFFEEE8DD),
    surface: TablTokens.papier,
    surfaceBasse: Color(0xFFF5F0E6),
    texte: TablTokens.encre,
    texteDoux: TablTokens.encreDouce,
    texteSurPrimaire: TablTokens.papier,
    bordure: Color(0xFFD9D0BF),
    erreur: Color(0xFFB3392E),
  );

  /// Les couleurs de l'apparence en cours pour ce [context].
  static TablCouleurs of(BuildContext context) =>
      Theme.of(context).extension<TablCouleurs>() ?? sombre;

  // --- Styles de texte, dans la couleur de l'apparence -----------------

  TextStyle get titreAffichage =>
      TablTokens.titreAffichage.copyWith(color: texte);
  TextStyle get titreSerre => TablTokens.titreSerre.copyWith(color: texte);
  TextStyle get grandTitre => TablTokens.grandTitre.copyWith(color: texte);
  TextStyle get titre => TablTokens.titre.copyWith(color: texte);
  TextStyle get sousTitre => TablTokens.sousTitre.copyWith(color: texte);
  TextStyle get corps => TablTokens.corps.copyWith(color: texte);
  TextStyle get legende => TablTokens.legende.copyWith(color: texteDoux);
  TextStyle get logo => TablTokens.logo.copyWith(color: primaire);

  @override
  TablCouleurs copyWith({
    Color? primaire,
    Color? primaireFoncee,
    Color? fond,
    Color? surface,
    Color? surfaceBasse,
    Color? texte,
    Color? texteDoux,
    Color? texteSurPrimaire,
    Color? bordure,
    Color? erreur,
  }) => TablCouleurs(
    primaire: primaire ?? this.primaire,
    primaireFoncee: primaireFoncee ?? this.primaireFoncee,
    fond: fond ?? this.fond,
    surface: surface ?? this.surface,
    surfaceBasse: surfaceBasse ?? this.surfaceBasse,
    texte: texte ?? this.texte,
    texteDoux: texteDoux ?? this.texteDoux,
    texteSurPrimaire: texteSurPrimaire ?? this.texteSurPrimaire,
    bordure: bordure ?? this.bordure,
    erreur: erreur ?? this.erreur,
  );

  /// Le fondu d'un thème à l'autre quand on change d'apparence.
  @override
  TablCouleurs lerp(TablCouleurs? autre, double t) {
    if (autre == null) return this;
    return TablCouleurs(
      primaire: Color.lerp(primaire, autre.primaire, t)!,
      primaireFoncee: Color.lerp(primaireFoncee, autre.primaireFoncee, t)!,
      fond: Color.lerp(fond, autre.fond, t)!,
      surface: Color.lerp(surface, autre.surface, t)!,
      surfaceBasse: Color.lerp(surfaceBasse, autre.surfaceBasse, t)!,
      texte: Color.lerp(texte, autre.texte, t)!,
      texteDoux: Color.lerp(texteDoux, autre.texteDoux, t)!,
      texteSurPrimaire: Color.lerp(
        texteSurPrimaire,
        autre.texteSurPrimaire,
        t,
      )!,
      bordure: Color.lerp(bordure, autre.bordure, t)!,
      erreur: Color.lerp(erreur, autre.erreur, t)!,
    );
  }
}
