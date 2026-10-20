import 'emotion.dart';
import 'personne_presente.dart';
import 'presentation_souvenir.dart';
import 'souvenir_feed.dart';

/// Un mois du journal d'un profil : ses moments en grille, et en une
/// ligne avec qui et où ils ont eu lieu.
class MoisJournal {
  const MoisJournal({
    required this.annee,
    required this.mois,
    required this.titre,
    required this.compte,
    required this.personnes,
    required this.recit,
    required this.souvenirs,
    required this.indexVedette,
  });

  final int annee;
  final int mois;

  /// "Octobre".
  final String titre;

  /// "3 moments".
  final String compte;

  /// Les personnes les plus présentes ce mois-ci (3 au plus), pour leurs
  /// bulles.
  final List<PersonnePresente> personnes;

  /// "Arthur et Emma · Liège", "En solo · Milan".
  final String recit;

  /// Du plus récent au plus ancien.
  final List<SouvenirFeed> souvenirs;

  /// Le moment à mettre en grand dans la grille, `null` si aucun.
  final int? indexVedette;
}

/// "Toi" pour le compte courant, son pseudo sinon.
String nomPersonne(PersonnePresente personne) =>
    personne.estMoi ? 'Toi' : personne.pseudo;

/// Sous le nom du restaurant d'un moment agrandi : "Liège · 16 octobre
/// 2026 · Dîner".
String detailsMoment(SouvenirFeed s) => [
  if (s.ville.isNotEmpty) s.ville,
  '${s.dateVisite.day} ${nomDuMois(s.dateVisite.month)} ${s.dateVisite.year}',
  ?libelleMomentRepas(s.moment),
].join(' · ');

/// "Forno Rosso, 16 octobre" — ce que lit un lecteur d'écran sur sa
/// tuile.
String libelleTuileMoment(SouvenirFeed s) =>
    '${s.restaurantNom}, ${dateLisibleSouvenir(s.dateVisite)}';

/// "avec Arthur et toi" ; `null` si personne n'est tagué.
String? avecQuiMoment(SouvenirFeed s) => s.presents.isEmpty
    ? null
    : 'avec ${listeDeNoms([for (final p in s.presents) p.estMoi ? 'toi' : p.pseudo])}';

/// Les années qui ont au moins un moment, de la plus récente à la plus
/// ancienne.
List<int> anneesDuJournal(List<SouvenirFeed> souvenirs) {
  final annees = {for (final s in souvenirs) s.dateVisite.year}.toList()
    ..sort((a, b) => b.compareTo(a));
  return annees;
}

/// Les moments de [annee], regroupés par mois, du plus récent au plus
/// ancien.
List<MoisJournal> journalDeLAnnee(List<SouvenirFeed> souvenirs, int annee) {
  final parMois = <int, List<SouvenirFeed>>{};
  for (final s in parDateDecroissante(souvenirs)) {
    if (s.dateVisite.year != annee) continue;
    parMois.putIfAbsent(s.dateVisite.month, () => []).add(s);
  }
  return [
    for (final MapEntry(key: mois, value: duMois) in parMois.entries)
      _moisJournal(annee, mois, duMois),
  ];
}

MoisJournal _moisJournal(int annee, int mois, List<SouvenirFeed> duMois) {
  final personnes = personnesLesPlusPresentes(duMois);
  final villes = <String>{
    for (final s in duMois)
      if (s.ville.isNotEmpty) s.ville,
  };
  final avecQui = personnes.isEmpty
      ? 'En solo'
      : listeDeNoms(personnes.map(nomPersonne).toList());
  final nomMois = nomDuMois(mois);
  return MoisJournal(
    annee: annee,
    mois: mois,
    titre: '${nomMois[0].toUpperCase()}${nomMois.substring(1)}',
    compte: pluriel(duMois.length, 'moment'),
    personnes: personnes.take(3).toList(),
    recit: [avecQui, if (villes.isNotEmpty) villes.join(', ')].join(' · '),
    souvenirs: duMois,
    indexVedette: indexVedette(duMois),
  );
}

/// Les personnes présentes dans [souvenirs], de la plus fréquente à la
/// moins fréquente (à égalité : la plus récente d'abord).
List<PersonnePresente> personnesLesPlusPresentes(List<SouvenirFeed> souvenirs) {
  final parId = <String, PersonnePresente>{};
  final nombre = <String, int>{};
  for (final s in souvenirs) {
    for (final p in s.presents) {
      parId.putIfAbsent(p.id, () => p);
      nombre[p.id] = (nombre[p.id] ?? 0) + 1;
    }
  }
  final ids = parId.keys.toList();
  // `sort` n'est pas stable : on départage par l'ordre d'apparition.
  final rang = {for (var i = 0; i < ids.length; i++) ids[i]: i};
  ids.sort((a, b) {
    final ecart = nombre[b]!.compareTo(nombre[a]!);
    return ecart != 0 ? ecart : rang[a]!.compareTo(rang[b]!);
  });
  return [for (final id in ids) parId[id]!];
}

/// Comme la galerie photo de l'iPhone, un mois d'au moins trois
/// moments met son coup de cœur en grand : la grille garde du rythme.
/// Le plus récent d'entre eux s'il y en a plusieurs.
int? indexVedette(List<SouvenirFeed> duMois) {
  if (duMois.length < 3) return null;
  final index = duMois.indexWhere(estMarquant);
  return index == -1 ? null : index;
}

/// Coup de cœur ou inoubliable : un moment qui ressort.
bool estMarquant(SouvenirFeed s) =>
    s.emotion == Emotion.coupDeCoeur || s.emotion == Emotion.inoubliable;

/// La photo en haut du profil : son dernier moment marquant, à défaut
/// son dernier moment avec une photo ; `null` s'il n'y en a aucun.
String? photoCouverture(List<SouvenirFeed> souvenirs) {
  final tries = parDateDecroissante(souvenirs);
  for (final s in tries) {
    if (estMarquant(s) && s.photoUrl != null) return s.photoUrl;
  }
  for (final s in tries) {
    if (s.photoUrl != null) return s.photoUrl;
  }
  return null;
}

/// Ce que deux personnes ont vécu ensemble à table, vu depuis le profil
/// de l'autre.
class DuoProfils {
  const DuoProfils({
    required this.depuis,
    required this.resume,
    required this.souvenirs,
  });

  /// "À table ensemble depuis mars 2025".
  final String depuis;

  /// "7 moments ensemble, dans 5 adresses. Le dernier : Forno Rosso, le
  /// 16 octobre."
  final String resume;

  /// Ses moments où je suis tagué, et les miens où il l'est, du plus
  /// récent au plus ancien.
  final List<SouvenirFeed> souvenirs;
}

/// `null` si on n'a encore partagé aucun moment.
DuoProfils? duoAvec({
  required List<SouvenirFeed> sesMoments,
  required List<SouvenirFeed> mesMomentsAvecLui,
}) {
  final parId = <String, SouvenirFeed>{
    for (final s in sesMoments)
      if (s.presents.any((p) => p.estMoi)) s.id: s,
    for (final s in mesMomentsAvecLui) s.id: s,
  };
  if (parId.isEmpty) return null;
  final ensemble = parDateDecroissante(parId.values);
  final premier = ensemble.last.dateVisite;
  final dernier = ensemble.first;
  final adresses = {for (final s in ensemble) cleRestaurant(s)}.length;
  return DuoProfils(
    depuis:
        'À table ensemble depuis ${nomDuMois(premier.month)} ${premier.year}',
    resume:
        '${pluriel(ensemble.length, 'moment')} ensemble, dans '
        '${pluriel(adresses, 'adresse')}. Le dernier : '
        '${dernier.restaurantNom}, le ${dernier.dateVisite.day} '
        '${nomDuMois(dernier.dateVisite.month)}.',
    souvenirs: ensemble,
  );
}

/// Identifie un restaurant, même entré à la main sans identifiant.
String cleRestaurant(SouvenirFeed s) =>
    s.restaurantId ?? '${s.restaurantNom}|${s.ville}';

/// Du plus récent au plus ancien ; à date égale, l'ordre reçu est gardé
/// (`sort` seul ne le garantit pas).
List<SouvenirFeed> parDateDecroissante(Iterable<SouvenirFeed> souvenirs) {
  final liste = souvenirs.toList();
  final rang = {for (var i = 0; i < liste.length; i++) liste[i].id: i};
  return liste..sort((a, b) {
    final ecart = b.dateVisite.compareTo(a.dateVisite);
    return ecart != 0 ? ecart : rang[a.id]!.compareTo(rang[b.id]!);
  });
}
