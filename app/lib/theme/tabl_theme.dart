import 'package:flutter/material.dart';

import '../services/apparence/apparence.dart';
import 'tokens.dart';

/// Assemble les tokens en un thème Flutter utilisable par l'application.
///
/// L'app fait `MaterialApp(theme: TablTheme.clair(), darkTheme:
/// TablTheme.sombre(), themeMode: TablTheme.mode(apparence))`.
class TablTheme {
  const TablTheme._();

  static final ThemeData _clair = _construire(
    TablCouleurs.clair,
    Brightness.light,
  );
  static final ThemeData _sombre = _construire(
    TablCouleurs.sombre,
    Brightness.dark,
  );

  /// Le même objet à chaque appel : un écran qui force la nuit peut
  /// l'utiliser sans reconstruire un thème à chaque `build`.
  static ThemeData clair() => _clair;
  static ThemeData sombre() => _sombre;

  /// Le mode du `MaterialApp` pour l'apparence choisie : « Automatique »
  /// suit le téléphone.
  static ThemeMode mode(Apparence apparence) => switch (apparence) {
    Apparence.automatique => ThemeMode.system,
    Apparence.clair => ThemeMode.light,
    Apparence.sombre => ThemeMode.dark,
  };

  static ThemeData _construire(TablCouleurs c, Brightness brightness) {
    var schema = ColorScheme.fromSeed(
      seedColor: c.primaire,
      brightness: brightness,
      surface: c.surface,
    );
    if (brightness == Brightness.light) {
      schema = schema.copyWith(
        primary: c.primaire,
        onPrimary: c.texteSurPrimaire,
        onSurface: c.texte,
        error: c.erreur,
        outline: c.bordure,
      );
    }
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: schema,
    );

    return base.copyWith(
      scaffoldBackgroundColor: c.fond,
      extensions: [c],
      textTheme: base.textTheme.copyWith(
        titleLarge: c.titre,
        titleMedium: c.sousTitre,
        bodyMedium: c.corps,
        bodySmall: c.legende,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.fond,
        foregroundColor: c.texte,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: c.titre,
      ),
      dividerTheme: DividerThemeData(color: c.bordure, thickness: 1, space: 1),
    );
  }
}
