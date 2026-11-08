import 'candidat_date_proposition.dart';
import 'confirmation_proposition.dart';

/// Le détail complet d'une proposition (megaprompt Bloc 4) : au-delà du
/// GO/Je passe déjà couvert par [PropositionTable] (Bloc 3), le sondage
/// de dates, la confirmation et l'accès au mini-chat.
class DetailProposition {
  const DetailProposition({
    required this.id,
    required this.restaurantNom,
    required this.ville,
    required this.proposePar,
    required this.parMoi,
    required this.active,
    required this.etatTexte,
    required this.nombreGo,
    this.monInteret,
    this.candidats = const [],
    required this.progressionSoumis,
    required this.progressionEligibles,
    required this.moiAiSoumisReponse,
    this.confirmation,
    required this.peutAccederChat,
    required this.nombreMessages,
  });

  final String id;
  final String restaurantNom;
  final String ville;
  final String proposePar;
  final bool parMoi;

  /// `false` pour un état terminal (annulée/déclinée/expirée) — comme
  /// [PropositionTable.active].
  final bool active;
  final String etatTexte;

  final int nombreGo;
  final bool? monInteret;

  /// Vide tant que le creator n'a pas encore ouvert "Proposer des
  /// dates" (règle 6 : zéro date au départ est un flow valide).
  final List<CandidatDateProposition> candidats;

  /// Règle 22 : "4/6 ont répondu" — jamais qui, juste la progression.
  final int progressionSoumis;
  final int progressionEligibles;

  /// Distingue "pas encore répondu" de "a répondu, 0 jour" (règle 21) —
  /// pour moi-même, pour savoir si "Envoyer mes disponibilités" ou
  /// "Modifier mes disponibilités" doit s'afficher.
  final bool moiAiSoumisReponse;

  /// `null` tant qu'aucune date n'est confirmée.
  final ConfirmationProposition? confirmation;

  /// Règle 41 : creator, ou membre actif ayant répondu GO.
  final bool peutAccederChat;

  final int nombreMessages;

  /// Y a-t-il un sondage de dates en cours (créé, mais pas confirmé) ?
  bool get sondageEnCours => candidats.isNotEmpty && confirmation == null;

  /// Règle 15-17 : les dates non passées qui conviennent à tout le
  /// monde, triées (la plus proche en premier — règle 16, "peut être
  /// présentée en premier comme suggestion").
  List<CandidatDateProposition> get datesCommunes {
    final communes = candidats
        .where((c) => !c.passee && c.toutLeMondeDisponible)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return communes;
  }

  /// Règle 17 : à défaut de date commune, les meilleurs compromis —
  /// triés par disponibilité décroissante.
  List<CandidatDateProposition> get meilleursCompromis {
    final restantes = candidats.where((c) => !c.passee).toList()
      ..sort((a, b) => b.disponibles.compareTo(a.disponibles));
    return restantes;
  }

  /// Règle 33 : si toutes les dates candidates sont passées, plus rien
  /// à sélectionner.
  bool get toutesLesDatesSontPassees =>
      candidats.isNotEmpty && candidats.every((c) => c.passee);

  /// Règle 54 : "Passé ≠ Réalisé" — état purement temporel, ne déclenche
  /// jamais la création d'un souvenir automatiquement.
  bool estPassee([DateTime? maintenant]) {
    final conf = confirmation;
    if (conf == null) return false;
    final ref = maintenant ?? DateTime.now();
    if (conf.heure == null) {
      // Pas d'heure : passé à partir du lendemain (règle 49, "fin de
      // journée locale + grace period" — simplifié ici à minuit+1j).
      final lendemain = DateTime(conf.date.year, conf.date.month, conf.date.day + 1);
      return !ref.isBefore(lendemain);
    }
    final parts = conf.heure!.split(':');
    final momentEvenement = DateTime(
      conf.date.year,
      conf.date.month,
      conf.date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    return ref.isAfter(momentEvenement);
  }

  /// Règle 49 : le mini-chat s'archive ~24h après l'événement.
  bool chatArchive([DateTime? maintenant]) {
    final conf = confirmation;
    if (conf == null) return false;
    final ref = maintenant ?? DateTime.now();
    final heureRef = conf.heure ?? '23:59';
    final parts = heureRef.split(':');
    final limite = DateTime(
      conf.date.year,
      conf.date.month,
      conf.date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    ).add(const Duration(hours: 24));
    return ref.isAfter(limite);
  }
}
