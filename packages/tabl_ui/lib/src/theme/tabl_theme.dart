import 'package:flutter/material.dart';

import 'tokens.dart';

/// Assemble les tokens en un thème Flutter utilisable par l'application.
///
/// L'app fait simplement `MaterialApp(theme: TablTheme.clair())`.
class TablTheme {
  const TablTheme._();

  static ThemeData clair() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: TablTokens.primaire,
        surface: TablTokens.surface,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: TablTokens.fond,
      textTheme: base.textTheme.copyWith(
        titleLarge: TablTokens.titre,
        titleMedium: TablTokens.sousTitre,
        bodyMedium: TablTokens.corps,
        bodySmall: TablTokens.legende,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: TablTokens.fond,
        foregroundColor: TablTokens.texte,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TablTokens.titre,
      ),
      dividerTheme: const DividerThemeData(
        color: TablTokens.bordure,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
