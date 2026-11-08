import 'package:flutter/material.dart';

import '../services/apparence/apparence.dart';
import 'tokens.dart';

/// L'apparence choisie, pour tout l'arbre : un écran demande
/// [TablApparence.claire] ou sa [PaletteExplorer] ; le réglage la change
/// par [TablApparence.choisir]. Sans elle (tests), tout est sombre.
class TablApparence extends InheritedNotifier<ValueNotifier<Apparence>> {
  const TablApparence({
    super.key,
    required ValueNotifier<Apparence> reglage,
    required super.child,
  }) : super(notifier: reglage);

  static Apparence of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<TablApparence>()
          ?.notifier
          ?.value ??
      Apparence.sombre;

  /// Clair pour de bon, le réglage du téléphone pris en compte — sauf
  /// sous une [TablNuitForcee] active.
  static bool claire(BuildContext context) {
    final nuit = context.dependOnInheritedWidgetOfExactType<TablNuitForcee>();
    if (nuit?.active ?? false) return false;
    return of(context).estClaire(
      telephoneClair:
          MediaQuery.platformBrightnessOf(context) == Brightness.light,
    );
  }

  static void choisir(BuildContext context, Apparence apparence) {
    final reglage = context
        .getInheritedWidgetOfExactType<TablApparence>()
        ?.notifier;
    reglage?.value = apparence;
  }
}

/// Sous elle, tout est sombre quel que soit le réglage, tant qu'elle est
/// [active] (la Constellation : un ciel de nuit). Posée en permanence et
/// seulement allumée ou éteinte, pour que l'arbre garde sa forme (et la
/// carte, son état).
class TablNuitForcee extends InheritedWidget {
  const TablNuitForcee({super.key, required this.active, required super.child});

  final bool active;

  @override
  bool updateShouldNotify(TablNuitForcee ancien) => ancien.active != active;
}

/// Les couleurs de l'Explorer : en clair, celles de la maquette de Martin
/// (fond de lin, tuiles nuit, braise et ivoire) ; en sombre, les mêmes
/// tuiles sur le fond nuit du reste de l'app.
class PaletteExplorer {
  const PaletteExplorer._({
    required this.fond,
    required this.texte,
    required this.texteDoux,
    required this.tuileCercle,
    required this.tuileVous,
    required this.contourVous,
    required this.barre,
    required this.barreBouton,
    required this.etoile,
    required this.surface,
    required this.trait,
    required this.apercu,
    required this.action,
    required this.repliBas,
  });

  /// Le fond de l'écran, et celui qui se voit dans l'encoche des tuiles.
  final Color fond;
  final Color texte;
  final Color texteDoux;

  /// Une adresse de mon cercle.
  final Color tuileCercle;

  /// Une adresse où je suis allé moi aussi.
  final Color tuileVous;
  final Color contourVous;

  /// La barre flottante du bas et ses boutons ronds.
  final Color barre;
  final Color barreBouton;

  /// L'étoile de la note, dans l'encoche.
  final Color etoile;

  /// Les feuilles posées sur l'écran (« Qui y est allé », recherche).
  final Color surface;
  final Color trait;

  /// La carte d'aperçu d'un lieu, posée en bas de la carte.
  final Color apercu;

  /// Les boutons secondaires de cette carte, et le haut du dégradé d'une
  /// photo absente ([repliBas] en est le bas).
  final Color action;
  final Color repliBas;

  /// Là où mes proches retournent : la même braise en clair et en sombre.
  Color get tuileRetour => const Color(0xFFAF4A2C);

  static const clair = PaletteExplorer._(
    fond: Color(0xFFEEE8DD),
    texte: TablTokens.encre,
    texteDoux: TablTokens.encreDouce,
    tuileCercle: Color(0xFF121B2E),
    tuileVous: Color(0xFFECE4D6),
    contourVous: TablTokens.encre,
    barre: TablTokens.encre,
    barreBouton: Color(0x17F5F0E8),
    etoile: Color(0xFFB07F2E),
    surface: TablTokens.papier,
    trait: Color(0x1407111F),
    apercu: Color(0xF2FBF8F2),
    action: Color(0xFFEFE8DB),
    repliBas: Color(0xFFD9D0BF),
  );

  static const sombre = PaletteExplorer._(
    fond: TablTokens.fond,
    texte: TablTokens.texte,
    texteDoux: Color(0xFFA7ABB4),
    tuileCercle: Color(0xFF172033),
    tuileVous: Color(0xFFECE4D6),
    contourVous: Color(0x00000000),
    barre: Color(0xFF1C2230),
    barreBouton: Color(0x1FF5F0E8),
    etoile: TablTokens.primaire,
    surface: Color(0xFF16181E),
    trait: Color(0x1AF5F0E8),
    apercu: Color(0xF20F1014),
    action: Color(0xFF1A1C21),
    repliBas: Color(0xFF0E1014),
  );

  static PaletteExplorer of(BuildContext context) =>
      TablApparence.claire(context) ? clair : sombre;
}
