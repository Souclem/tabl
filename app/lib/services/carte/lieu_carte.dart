import '../restaurants/categories_lieu.dart';
import '../souvenirs/emotion.dart';

/// Une visite visible sur la carte : un souvenir de mon réseau, réduit à
/// ce dont les filtres ont besoin (qui, quand, comment, dans quelle
/// Table).
class VisiteCarte {
  const VisiteCarte({
    required this.souvenirId,
    required this.auteurId,
    required this.auteurPseudo,
    required this.estMoi,
    required this.moment,
    required this.date,
    this.emotion,
    this.tableIds = const {},
  });

  final String souvenirId;
  final String auteurId;
  final String auteurPseudo;
  final bool estMoi;

  /// `'midi'` ou `'soir'`.
  final String moment;
  final DateTime date;
  final Emotion? emotion;

  /// Tables auxquelles ce souvenir est associé (parmi celles qu'on peut
  /// voir).
  final Set<String> tableIds;
}

/// Un lieu affichable sur la carte : soit entré dans Tabl (visité par
/// mon réseau, ou mis en envie), soit seulement présent dans l'annuaire.
class LieuCarte {
  const LieuCarte({
    required this.nom,
    required this.ville,
    required this.latitude,
    required this.longitude,
    this.restaurantId,
    this.fsqPlaceId,
    this.adresse,
    this.categories = const [],
    this.visites = const [],
    this.estEnvie = false,
  });

  final String nom;
  final String ville;
  final double latitude;
  final double longitude;

  /// `null` pour un lieu qui n'est encore que dans l'annuaire.
  final String? restaurantId;
  final String? fsqPlaceId;
  final String? adresse;
  final List<String> categories;
  final List<VisiteCarte> visites;

  /// Dans mes envies.
  final bool estEnvie;

  /// Identifiant stable sur la carte, quelle que soit l'origine du lieu.
  String get cle => restaurantId ?? 'fsq:$fsqPlaceId';

  /// Mis en avant (marqueur doré) : visité par mon réseau ou mis en
  /// envie — par opposition aux simples points de l'annuaire.
  bool get duReseau => visites.isNotEmpty || estEnvie;

  bool get visiteParMoi => visites.any((v) => v.estMoi);

  /// "Italien · Rue du Pont 16, Liège".
  String get description {
    final morceaux = [
      if (categories.isNotEmpty) libelleCategorie(categories.first),
      [?adresse, if (ville.isNotEmpty) ville].join(', '),
    ];
    return morceaux.where((m) => m.isNotEmpty).join(' · ');
  }

  /// "Emma, Thomas et 2 autres y sont allés" / "Vous y êtes allé" —
  /// jamais un chiffre seul, comme sur le Feed.
  String get resumeVisites {
    if (visites.isEmpty) {
      return estEnvie ? 'Dans vos envies' : 'Personne de votre réseau n\'y est allé';
    }
    final autres = {
      for (final v in visites)
        if (!v.estMoi) v.auteurId: v.auteurPseudo,
    }.values.toList();
    if (autres.isEmpty) return 'Vous y êtes allé';
    final tete = autres.take(2).join(', ');
    final reste = autres.length - 2;
    final verbe = autres.length > 1 ? 'y sont allés' : 'y est allé';
    final qui = reste > 0 ? '$tete et $reste autre${reste > 1 ? 's' : ''}' : tete;
    return visiteParMoi ? '$qui et vous y êtes allés' : '$qui $verbe';
  }
}

/// Une zone rectangulaire de la carte (ce qui est visible à l'écran).
class ZoneCarte {
  const ZoneCarte({
    required this.sud,
    required this.ouest,
    required this.nord,
    required this.est,
  });

  final double sud;
  final double ouest;
  final double nord;
  final double est;
}
