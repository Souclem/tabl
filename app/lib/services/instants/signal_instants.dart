/// Le signal Instants d'une expérience — de quoi composer "3 nouveaux
/// Instants" / "3 Instants" sur un post (règle 7-8), décider d'afficher
/// "À table maintenant" (règle 11) et trier sa sheet (règle 13), et
/// montrer ou non le CTA "+ Instant" sur sa propre publication
/// (règle 4).
class SignalInstants {
  const SignalInstants({
    required this.total,
    required this.nonVus,
    required this.fenetreCreationOuverte,
    this.plusRecentActifLe,
  });

  static const aucun = SignalInstants(
    total: 0,
    nonVus: 0,
    fenetreCreationOuverte: false,
  );

  /// Nombre d'Instants actifs (non expirés socialement) sur l'expérience.
  final int total;

  /// Parmi [total], combien le compte courant n'a pas encore vus.
  final int nonVus;

  /// `true` dans les 6h suivant la publication du parent (règle 4) —
  /// seul intérêt pour le propriétaire, ignoré pour les autres.
  final bool fenetreCreationOuverte;

  /// Date de création du plus récent Instant actif — sert au tri de "À
  /// table maintenant" (règle 13 : activité la plus récente).
  final DateTime? plusRecentActifLe;

  bool get aDesInstants => total > 0;
}
