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

/// Sous les étoiles de « Ce qui ressort ».
const noteEtoiles =
    'Touchez ou glissez sur les étoiles. Tout est facultatif ; rien n\'est '
    'jamais moyenné ni montré sur la fiche du restaurant.';

/// Les cinq catégories, dans l'ordre d'affichage.
const categoriesEtoiles = [
  CategorieEtoiles('cuisine', 'La cuisine'),
  CategorieEtoiles('ambiance', 'Ambiance'),
  CategorieEtoiles('service', 'Service'),
  CategorieEtoiles('lieu', 'Lieu'),
  CategorieEtoiles('qualite_prix', 'Qualité-prix'),
];

// --- Les plats notés de « Ce qui ressort » --------------------------------
//
// En plus des cinq catégories, on peut écrire le nom d'un plat (ou d'un
// vin…) et le noter : cinq au plus par moment. Dans le brouillon, ils
// vivent avec les catégories, sous une clé `plat:<nom>`, dans l'ordre où
// on les a écrits (note 0 tant qu'ils ne sont pas notés).

/// Cinq plats notés au plus par moment.
const nombreMaxPlats = 5;

/// Le nom d'un plat : 40 caractères au plus.
const longueurMaxPlat = 40;

const _prefixePlat = 'plat:';

/// La clé d'un plat dans les étoiles du brouillon.
String clePlat(String nom) => '$_prefixePlat${nom.trim()}';

bool estClePlat(String cle) => cle.startsWith(_prefixePlat);

/// « Risotto » pour `plat:Risotto`.
String nomPlat(String cle) => cle.substring(_prefixePlat.length);

/// Les clés des plats écrits, dans l'ordre où on les a écrits.
List<String> clesPlats(Map<String, int> etoiles) => [
  for (final cle in etoiles.keys)
    if (estClePlat(cle)) cle,
];

/// On peut encore écrire un plat.
bool peutAjouterPlat(Map<String, int> etoiles) =>
    clesPlats(etoiles).length < nombreMaxPlats;

/// Pourquoi [nom] ne peut pas s'ajouter aux plats, `null` s'il le peut.
String? validationPlat(String nom, Map<String, int> etoiles) {
  final propre = nom.trim();
  if (propre.isEmpty) return 'Écrivez le nom d\'un plat.';
  if (propre.runes.length > longueurMaxPlat) {
    return '$longueurMaxPlat caractères maximum.';
  }
  if (!peutAjouterPlat(etoiles)) return libelleLimitePlats;
  final minuscule = propre.toLowerCase();
  if (clesPlats(etoiles).any((c) => nomPlat(c).toLowerCase() == minuscule)) {
    return 'Ce plat est déjà noté.';
  }
  return null;
}

/// Ce qui remplace le champ quand cinq plats sont écrits.
const libelleLimitePlats = 'Cinq plats au maximum.';

/// Petit-déjeuner, déjeuner, goûter ou dîner, d'après l'heure. Affichage
/// seulement : le moment stocké reste matin, midi ou soir.
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
/// heure exacte n'est pas gardée, seulement le moment du repas.
String dateLisibleMomentPublie(
  DateTime dateVisite,
  String moment, {
  DateTime? maintenant,
}) {
  final ref = maintenant ?? DateTime.now();
  final repas = (libelleMomentRepas(moment) ?? 'Dîner').toLowerCase();
  return '${_jourLisible(dateVisite, ref)} · $repas';
}

/// Ce que le bouton principal de la finalisation propose : publier (ou
/// enregistrer). Les photos sont déjà choisies — la caméra ne laisse
/// continuer qu'avec une à dix. Sans lieu, « Publier » demande d'abord où
/// l'on était. Sans émotion, le bouton est grisé.
enum EtapeFinalisation {
  publier('Publier'),
  enregistrer('Enregistrer');

  const EtapeFinalisation(this.libelle);

  final String libelle;
}

/// L'étape du bouton principal. En modification, les photos et le lieu
/// sont déjà là : on enregistre.
EtapeFinalisation etapeFinalisation({required bool modification}) =>
    modification ? EtapeFinalisation.enregistrer : EtapeFinalisation.publier;

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

/// « AT » pour « Atelier Sauvenière » : le rond d'un restaurant dans une
/// liste, faute de photo.
String initialesLieu(String nom) {
  final lettres = nom.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
  return String.fromCharCodes(lettres.runes.take(2)).toUpperCase();
}
