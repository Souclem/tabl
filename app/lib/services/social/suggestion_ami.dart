import 'profil_public.dart';

/// Quelqu'un que l'on connaît peut-être, et ce qui le relie à moi. La
/// base donne les liens (`suggestions_amis()`), on en tire ici l'ordre
/// et la phrase.
class SuggestionAmi {
  const SuggestionAmi({
    required this.profil,
    this.momentsCommuns = 0,
    this.amisCommuns = 0,
    this.nomsAmisCommuns = const [],
  });

  /// La personne ; [ProfilPublic.meSuit] : elle me suit déjà.
  final ProfilPublic profil;

  /// Les moments où nous étions ensemble (l'un a tagué l'autre, ou
  /// quelqu'un nous a tagués tous les deux).
  final int momentsCommuns;

  /// Les gens que je suis qui la suivent.
  final int amisCommuns;

  /// Deux d'entre eux au plus, pour « Suivi par emma et léo ».
  final List<String> nomsAmisCommuns;

  String get id => profil.id;

  SuggestionAmi copierAvec({StatutAbonnement? statut}) => SuggestionAmi(
    profil: profil.copierAvec(statut: statut),
    momentsCommuns: momentsCommuns,
    amisCommuns: amisCommuns,
    nomsAmisCommuns: nomsAmisCommuns,
  );
}

/// Pas plus de suggestions à la fois : on propose des proches, pas un
/// annuaire.
const int nombreMaxSuggestions = 10;

/// Les suggestions à montrer, la plus sûre d'abord : quelqu'un qui me
/// suit, puis quelqu'un avec qui j'étais à table, puis les amis d'amis.
List<SuggestionAmi> classerSuggestions(Iterable<SuggestionAmi> candidats) {
  int poids(SuggestionAmi s) =>
      (s.profil.meSuit ? 100 : 0) +
      (s.momentsCommuns > 0 ? 40 + 5 * (s.momentsCommuns - 1) : 0) +
      10 * s.amisCommuns;
  final classees = [...candidats]
    ..sort((a, b) {
      final ecart = poids(b) - poids(a);
      return ecart != 0 ? ecart : a.profil.pseudo.compareTo(b.profil.pseudo);
    });
  return classees.take(nombreMaxSuggestions).toList();
}

/// Pourquoi on la propose, en une ligne : la raison la plus forte.
String raisonSuggestion(SuggestionAmi s) {
  if (s.profil.meSuit) return 'Vous suit';
  if (s.momentsCommuns == 1) return 'Avec vous dans un moment';
  if (s.momentsCommuns > 1) return 'Avec vous dans ${s.momentsCommuns} moments';
  final noms = s.nomsAmisCommuns;
  if (noms.isEmpty) return 'Dans votre entourage';
  final autres = s.amisCommuns - 1;
  if (autres <= 0 || noms.length == 1) return 'Suivi par ${noms.first}';
  if (autres == 1) return 'Suivi par ${noms[0]} et ${noms[1]}';
  return 'Suivi par ${noms.first} et $autres autres';
}

/// Le bouton d'une suggestion : la suivre, ou où en est mon suivi une
/// fois qu'elle l'est.
String libelleSuivreSuggestion(SuggestionAmi s) => switch (s.profil.statut) {
  StatutAbonnement.abonne => 'Abonné',
  StatutAbonnement.demandeEnvoyee => 'Demande envoyée',
  _ => s.profil.meSuit ? 'Suivre en retour' : 'Suivre',
};
