/// La fenêtre temporelle qui détermine quelles visites comptent pour la
/// taille des marqueurs et la récurrence (megaprompt Bloc 1, règle 5).
/// Un filtre, jamais un code couleur.
enum PeriodeCarte {
  troisMois,
  unAn,
  tout;

  /// La date la plus ancienne encore pertinente, ou `null` pour [tout]
  /// (aucune borne).
  DateTime? depuis(DateTime maintenant) {
    switch (this) {
      case PeriodeCarte.troisMois:
        return DateTime(maintenant.year, maintenant.month - 3, maintenant.day);
      case PeriodeCarte.unAn:
        return DateTime(maintenant.year - 1, maintenant.month, maintenant.day);
      case PeriodeCarte.tout:
        return null;
    }
  }
}
