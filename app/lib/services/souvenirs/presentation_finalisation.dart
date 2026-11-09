import 'presentation_souvenir.dart';
import 'precompletion_souvenir.dart';
import 'suivi_publication.dart';

/// « Ajouter un mot » : 300 caractères au plus.
const longueurMaxMot = 300;

/// Le compteur n'apparaît qu'à l'approche de la limite.
const seuilCompteurMot = 250;

/// « 270 / 300 » à partir de 250 caractères ; `null` avant.
String? compteurMot(int longueur) =>
    longueur >= seuilCompteurMot ? '$longueur / $longueurMaxMot' : null;

/// Une catégorie d'étoiles facultatives (« Ce qui ressort »).
class CategorieEtoiles {
  const CategorieEtoiles(this.cle, this.libelle);

  /// La clé stockée dans `souvenirs.notes` (`{"cuisine": 4}`).
  final String cle;
  final String libelle;
}

/// Les cinq catégories, dans l'ordre d'affichage.
const categoriesEtoiles = [
  CategorieEtoiles('cuisine', 'La cuisine'),
  CategorieEtoiles('ambiance', 'Ambiance'),
  CategorieEtoiles('service', 'Service'),
  CategorieEtoiles('lieu', 'Lieu'),
  CategorieEtoiles('qualite_prix', 'Qualité-prix'),
];

/// Petit-déjeuner, déjeuner, goûter ou dîner, d'après l'heure. Affichage
/// seulement : le moment stocké reste midi ou soir.
String repasDApresHeure(DateTime heure) {
  final h = heure.hour;
  if (h >= 5 && h < 10) return 'petit-déjeuner';
  if (h >= 10 && h < 15) return 'déjeuner';
  if (h >= 15 && h < 18) return 'goûter';
  return 'dîner';
}

String _jourLisible(DateTime date, DateTime maintenant) {
  final jour = DateTime(date.year, date.month, date.day);
  final aujourdhui = DateTime(
    maintenant.year,
    maintenant.month,
    maintenant.day,
  );
  final ecart = aujourdhui.difference(jour).inDays;
  if (ecart == 0) return 'Aujourd’hui';
  if (ecart == 1) return 'Hier';
  return dateLisibleSouvenir(date, maintenant: maintenant);
}

/// La date d'un moment en cours de création : « Aujourd'hui · déjeuner ·
/// 12 h 30 ».
String dateLisibleBrouillon(DateTime priseLe, {DateTime? maintenant}) {
  final ref = maintenant ?? DateTime.now();
  return '${_jourLisible(priseLe, ref)} · ${repasDApresHeure(priseLe)} · '
      '${heureLisible(priseLe)}';
}

/// La date d'un moment déjà publié, qu'on modifie : « Hier · dîner ». Son
/// heure exacte n'est pas gardée, seulement midi ou soir.
String dateLisibleMomentPublie(
  DateTime dateVisite,
  String moment, {
  DateTime? maintenant,
}) {
  final ref = maintenant ?? DateTime.now();
  final repas = moment == 'midi' ? 'déjeuner' : 'dîner';
  return '${_jourLisible(dateVisite, ref)} · $repas';
}

/// Ce que le bouton principal de la finalisation propose, dans l'ordre :
/// d'abord des photos, puis un lieu, puis publier (ou enregistrer).
enum EtapeFinalisation {
  choisirPhotos('Choisir les photos'),
  choisirLieu('Où étiez-vous ?'),
  publier('Publier'),
  enregistrer('Enregistrer');

  const EtapeFinalisation(this.libelle);

  final String libelle;

  /// Publier et enregistrer exigent l'émotion : sans elle le bouton est
  /// grisé.
  bool get exigeEmotion => this == publier || this == enregistrer;
}

/// L'étape du bouton principal. En modification, les photos et le lieu
/// sont déjà là : on enregistre.
EtapeFinalisation etapeFinalisation({
  required bool modification,
  required bool aDesPhotos,
  required bool aUnLieu,
}) {
  if (modification) return EtapeFinalisation.enregistrer;
  if (!aDesPhotos) return EtapeFinalisation.choisirPhotos;
  if (!aUnLieu) return EtapeFinalisation.choisirLieu;
  return EtapeFinalisation.publier;
}

/// La suite que l'appelant tire d'un [ResultatCloche] : faut-il montrer le
/// Fil (rafraîchi, le nouveau moment en haut), et ce qu'il reste à dire.
typedef SuiteCloche = ({bool montrerLeFil, String? message});

/// Le passage de relais après la cloche.
/// - publié ou déjà publié : le Fil repart de zéro et montre le moment, sans
///   message (sauf Tables en échec : le moment est publié, on le dit sans
///   en faire une erreur) ;
/// - annulé, brouillon gardé, en attente : rien ne change, un message dit où
///   est le moment ;
/// - modifier : la finalisation n'a jamais été quittée, rien à faire.
SuiteCloche suiteApresCloche(ResultatCloche resultat) {
  final publie =
      resultat.issue == IssueCloche.publie ||
      resultat.issue == IssueCloche.dejaPublie;
  if (publie && resultat.tablesEnEchec.isNotEmpty) {
    return (
      montrerLeFil: true,
      message:
          'Publié, mais impossible de le partager avec '
          '${pluriel(resultat.tablesEnEchec.length, 'Table')}.',
    );
  }
  return switch (resultat.issue) {
    IssueCloche.publie ||
    IssueCloche.dejaPublie => (montrerLeFil: true, message: null),
    IssueCloche.modifier => (montrerLeFil: false, message: null),
    IssueCloche.annule => (
      montrerLeFil: false,
      message: 'Publication annulée. Votre moment est gardé sur ce téléphone.',
    ),
    IssueCloche.brouillonGarde => (
      montrerLeFil: false,
      message: 'Votre moment est gardé sur ce téléphone.',
    ),
    IssueCloche.enAttente => (
      montrerLeFil: false,
      message: 'Votre moment sera envoyé dès que possible.',
    ),
  };
}
