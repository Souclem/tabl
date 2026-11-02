import 'dart:math' as math;

import '../restaurants/categories_lieu.dart';
import '../restaurants/distance.dart';
import 'lieu_carte.dart';

/// Ce que vaut chaque ressenti sur 5, pour « l'avis du cercle ». Calculé
/// ici, jamais en base : c'est une règle de lecture, pas une donnée.
const Map<String, double> valeurRessentis = {
  '😍': 5,
  '🤩': 5,
  '🙂': 3.5,
  '😐': 2,
};

/// La moyenne des ressentis sur 5, `null` sans aucun ressenti reconnu.
double? noteSurCinq(Iterable<String> ressentis) {
  final valeurs = [
    for (final r in ressentis) ?valeurRessentis[r],
  ];
  if (valeurs.isEmpty) return null;
  return valeurs.reduce((a, b) => a + b) / valeurs.length;
}

/// "4,6".
String noteLisible(double note) =>
    note.toStringAsFixed(1).replaceAll('.', ',');

/// "aujourd'hui", "hier", "il y a 3 jours", "il y a 2 semaines", "il y
/// a 4 mois", "il y a 2 ans".
String ilYA(DateTime date, DateTime maintenant) {
  final jour = DateTime(date.year, date.month, date.day);
  final aujourdhui = DateTime(maintenant.year, maintenant.month, maintenant.day);
  final jours = aujourdhui.difference(jour).inDays;
  if (jours <= 0) return 'aujourd\'hui';
  if (jours == 1) return 'hier';
  if (jours < 14) return 'il y a $jours jours';
  if (jours < 60) return 'il y a ${jours ~/ 7} semaines';
  if (jours < 365) return 'il y a ${jours ~/ 30} mois';
  final ans = jours ~/ 365;
  return ans == 1 ? 'il y a un an' : 'il y a $ans ans';
}

/// "Emma la connaît", "Emma et Martin la connaissent", "Emma, Martin +2
/// la connaissent".
String quiLaConnait(LieuCarte lieu) {
  final noms = [for (final v in lieu.visages) v.pseudo];
  final total = math.max(lieu.amis, noms.length);
  if (noms.isEmpty) {
    return total == 1
        ? 'Un proche la connaît'
        : '$total proches la connaissent';
  }
  if (total == 1) return '${noms.first} la connaît';
  if (total == 2 && noms.length >= 2) {
    return '${noms[0]} et ${noms[1]} la connaissent';
  }
  final deux = noms.take(2).join(', ');
  final autres = total - math.min(2, noms.length);
  return autres > 0 ? '$deux +$autres la connaissent' : '$deux la connaissent';
}

/// La phrase dorée qui dit pourquoi ce lieu compte : que le cercle y
/// revient, qu'il a été un coup de cœur, ou qu'on y est passé tout
/// récemment. `null` : rien de plus à dire que « qui la connaît ».
String? signalLieu(LieuCarte lieu, DateTime maintenant) {
  final revenants = lieu.amisQuiReviennent;
  if (revenants >= 2) return '$revenants de vos proches y retournent';
  if (revenants == 1) return 'Votre cercle revient ici';
  if (lieu.coupsDeCoeur >= 2) return '${lieu.coupsDeCoeur} coups de cœur';
  if (lieu.coupsDeCoeur == 1) return 'Un coup de cœur dans votre cercle';
  final derniere = lieu.derniereVisite;
  if (derniere != null && maintenant.difference(derniere).inDays < 14) {
    return 'Dernière visite ${ilYA(derniere, maintenant)}';
  }
  return null;
}

/// Ce que dit la couleur d'une tuile de l'Explorer.
enum TeinteLieu {
  /// Mon cercle y est allé.
  cercle,

  /// Mes proches y retournent.
  retour,

  /// J'y suis allé moi aussi : ça prime.
  vous,
}

TeinteLieu teinteLieu(LieuCarte lieu) => lieu.visiteParMoi
    ? TeinteLieu.vous
    : lieu.leCercleRevient
    ? TeinteLieu.retour
    : TeinteLieu.cercle;

/// Le nombre de proches au-delà des visages montrés : "+4", jamais plus
/// de "+10" ([nombreux] : au-delà, la pastille se dore). `null` : tous
/// les visages sont là.
({String texte, bool nombreux})? autresQueLesVisages(LieuCarte lieu) {
  final autres = lieu.amis - lieu.visages.length;
  if (autres <= 0) return null;
  return (texte: '+${math.min(autres, 10)}', nombreux: autres > 10);
}

/// La cuisine d'une adresse ("Japonais"), à défaut son quartier ou sa
/// ville.
String? cuisineOuLieu(LieuCarte lieu) {
  if (lieu.categories.isNotEmpty) return libelleCategorie(lieu.categories.first);
  final quartier = lieu.quartier?.trim();
  if (quartier != null && quartier.isNotEmpty) return quartier;
  return lieu.ville.isEmpty ? null : lieu.ville;
}

/// Au-delà, la distance ne dit plus rien d'utile sur une tuile
/// (« 8 955 km ») : on la tait.
const double distanceMaxSurTuile = 50000;

/// "50 m", "1,4 km" ; `null` si on ne sait pas ou si c'est trop loin.
String? distanceSurTuile(double? metres) =>
    metres == null || metres > distanceMaxSurTuile
    ? null
    : distanceLisible(metres);

/// Une adresse dans la recherche de l'Explorer : "4 proches y
/// retournent · Italien · Liège", "1 proche · Japonais · Namur".
String resumeRecherche(LieuCarte lieu) {
  final qui = switch ((lieu.amisQuiReviennent, lieu.amis)) {
    (1, _) => '1 proche y retourne',
    (final n, _) when n > 1 => '$n proches y retournent',
    (_, 1) => '1 proche',
    (_, final n) when n > 1 => '$n proches',
    _ => lieu.visiteParMoi ? 'Vous y êtes allé' : null,
  };
  return [
    ?qui,
    if (lieu.categories.isNotEmpty) libelleCategorie(lieu.categories.first),
    if (lieu.ville.isNotEmpty) lieu.ville,
  ].join(' · ');
}

/// "Italien · Hors-Château" : la cuisine et le quartier (ou la ville).
String cuisineEtQuartier(LieuCarte lieu) {
  final quartier = lieu.quartier?.trim();
  return [
    if (lieu.categories.isNotEmpty) libelleCategorie(lieu.categories.first),
    if (quartier != null && quartier.isNotEmpty)
      quartier
    else if (lieu.ville.isNotEmpty)
      lieu.ville,
  ].join(' · ');
}

/// Les façons de trier les adresses du cercle, chacune avec ce qu'elle
/// fait (le menu « Trié par » le dit sous son nom).
enum TriCercle {
  recents('Récents', 'Les dernières visites de vos proches'),
  ilsYRetournent('Ils y retournent', 'Là où le plus de proches retournent'),
  mieuxNotes('Mieux notés', 'Les mieux notées par vos proches d’abord'),
  plusProches('Plus proches', 'Du plus proche au plus loin de vous'),
  plusConnus('Les plus connus', 'Là où le plus de proches sont allés');

  const TriCercle(this.libelle, this.description);

  final String libelle;
  final String description;
}

/// [lieux] dans l'ordre de [tri]. Sans [position], « Plus proches »
/// garde l'ordre reçu. À égalité, l'ordre reçu (les plus connus
/// d'abord) départage.
List<LieuCarte> trierLieux(
  List<LieuCarte> lieux,
  TriCercle tri, {
  ({double latitude, double longitude})? position,
}) {
  final rang = {for (var i = 0; i < lieux.length; i++) lieux[i].cle: i};
  int ordreRecu(LieuCarte a, LieuCarte b) =>
      rang[a.cle]!.compareTo(rang[b.cle]!);
  int puis(int ecart, LieuCarte a, LieuCarte b) =>
      ecart != 0 ? ecart : ordreRecu(a, b);
  final ancien = DateTime(1900);
  final copie = [...lieux];
  switch (tri) {
    case TriCercle.recents:
      copie.sort(
        (a, b) => puis(
          (b.derniereVisite ?? ancien).compareTo(a.derniereVisite ?? ancien),
          a,
          b,
        ),
      );
    case TriCercle.ilsYRetournent:
      copie.sort(
        (a, b) => puis(
          b.amisQuiReviennent != a.amisQuiReviennent
              ? b.amisQuiReviennent.compareTo(a.amisQuiReviennent)
              : b.visites.compareTo(a.visites),
          a,
          b,
        ),
      );
    case TriCercle.mieuxNotes:
      copie.sort((a, b) {
        final na = noteSurCinq(a.ressentis) ?? 0;
        final nb = noteSurCinq(b.ressentis) ?? 0;
        if (na != nb) return nb.compareTo(na);
        return puis(b.ressentis.length.compareTo(a.ressentis.length), a, b);
      });
    case TriCercle.plusProches:
      final p = position;
      if (p != null) {
        double d(LieuCarte l) =>
            distanceEnMetres(p.latitude, p.longitude, l.latitude, l.longitude);
        copie.sort((a, b) => puis(d(a).compareTo(d(b)), a, b));
      }
    case TriCercle.plusConnus:
      copie.sort(
        (a, b) => puis(
          b.amis != a.amis
              ? b.amis.compareTo(a.amis)
              : b.visites.compareTo(a.visites),
          a,
          b,
        ),
      );
  }
  return copie;
}

/// Une ville où mon cercle a des adresses : son centre, sa zone, et
/// combien elle en compte.
class VilleCercle {
  const VilleCercle({
    required this.nom,
    required this.compte,
    required this.zone,
  });

  final String nom;
  final int compte;
  final ZoneCarte zone;

  double get latitude => (zone.sud + zone.nord) / 2;
  double get longitude => (zone.ouest + zone.est) / 2;
}

/// Les villes de [lieux], de la plus fournie à la moins fournie (à
/// égalité, par ordre alphabétique). La casse et les espaces ne
/// séparent pas deux villes (« liège » et « Liège »).
List<VilleCercle> villesDuCercle(Iterable<LieuCarte> lieux) {
  final parVille = <String, List<LieuCarte>>{};
  final noms = <String, String>{};
  for (final l in lieux) {
    final nom = l.ville.trim();
    if (nom.isEmpty) continue;
    final cle = normaliserPourRecherche(nom);
    parVille.putIfAbsent(cle, () => []).add(l);
    noms.putIfAbsent(cle, () => nom);
  }
  final villes = [
    for (final MapEntry(key: cle, value: ici) in parVille.entries)
      VilleCercle(
        nom: noms[cle]!,
        compte: ici.length,
        zone: ZoneCarte(
          sud: ici.map((l) => l.latitude).reduce(math.min),
          ouest: ici.map((l) => l.longitude).reduce(math.min),
          nord: ici.map((l) => l.latitude).reduce(math.max),
          est: ici.map((l) => l.longitude).reduce(math.max),
        ),
      ),
  ];
  villes.sort(
    (a, b) => a.compte != b.compte
        ? b.compte.compareTo(a.compte)
        : a.nom.compareTo(b.nom),
  );
  return villes;
}

/// La ville la plus proche de ce qu'on regarde, si elle est à moins de
/// [maxKm] ; `null` sinon (on regarde trop loin, ou nulle part).
VilleCercle? villeRegardee(
  List<VilleCercle> villes,
  double latitude,
  double longitude, {
  double maxKm = 25,
}) {
  VilleCercle? meilleure;
  var meilleureDistance = maxKm * 1000;
  for (final v in villes) {
    final d = distanceEnMetres(latitude, longitude, v.latitude, v.longitude);
    if (d < meilleureDistance) {
      meilleure = v;
      meilleureDistance = d;
    }
  }
  return meilleure;
}

/// "12 adresses connues par vos proches", "1 adresse…", ou "Aucune
/// adresse de vos proches ici".
String adressesDuCercle(int nombre) => switch (nombre) {
  0 => 'Aucune adresse de vos proches ici',
  1 => '1 adresse connue par vos proches',
  _ => '$nombre adresses connues par vos proches',
};
