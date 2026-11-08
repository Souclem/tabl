import 'dart:math' as math;

import '../souvenirs/journal_profil.dart';
import '../souvenirs/personne_presente.dart';
import '../souvenirs/presentation_souvenir.dart';
import '../souvenirs/souvenir_feed.dart';
import 'presentation_carte.dart';

/// Un proche, sur la fiche d'un restaurant.
typedef ProcheFiche = ({
  String id,
  String pseudo,
  String? photoUrl,
  int fois,

  /// Sa dernière visite ici, et le ressenti qu'il en a gardé.
  DateTime derniere,
  String? emoji,
});

/// Ce que la fiche d'un restaurant raconte, tiré des moments de mon
/// cercle ici (les miens compris) : l'avis du cercle, qui le connaît, qui
/// y retourne, qui l'a découvert le premier, mon histoire ici et ce qui
/// ressort.
class ResumeFiche {
  const ResumeFiche({
    required this.note,
    required this.avis,
    required this.sansAvis,
    required this.emojiDominant,
    required this.connaissent,
    required this.yRetournent,
    required this.premiereDecouverte,
    required this.mesFois,
    required this.maPremiere,
    required this.maDerniere,
    required this.ceQuiRessort,
    required this.photoUrl,
  });

  /// L'avis du cercle sur 5, `null` sans aucun ressenti de mes proches.
  final double? note;

  /// Moments de mes proches avec un ressenti ; ceux sans.
  final int avis;
  final int sansAvis;
  final String? emojiDominant;

  /// Mes proches qui y sont allés, les plus fidèles d'abord.
  final List<ProcheFiche> connaissent;

  /// Ceux qui y sont allés au moins deux fois.
  final List<ProcheFiche> yRetournent;

  /// Le premier de mes proches à y être allé, et l'année.
  final ({ProcheFiche proche, int annee})? premiereDecouverte;

  final int mesFois;
  final DateTime? maPremiere;
  final DateTime? maDerniere;

  /// "Assiette exceptionnelle" et le nombre de fois où ça a été dit, du
  /// plus dit au moins dit.
  final List<({String libelle, int fois})> ceQuiRessort;

  /// La photo la plus récente.
  final String? photoUrl;

  bool get estVide => connaissent.isEmpty && mesFois == 0;
}

ResumeFiche resumerFiche(List<SouvenirFeed> moments) {
  final duPlusAncien = [...parDateDecroissante(moments)].reversed.toList();
  final deProches = [
    for (final m in moments)
      if (!m.estAMoi) m,
  ];
  final miens = [
    for (final m in moments)
      if (m.estAMoi) m,
  ];

  final ressentis = [for (final m in deProches) ?m.emotion?.emoji];
  final parEmoji = <String, int>{};
  for (final e in ressentis) {
    parEmoji[e] = (parEmoji[e] ?? 0) + 1;
  }
  final emojiDominant = parEmoji.entries.isEmpty
      ? null
      : (parEmoji.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;

  // Chaque proche, combien de fois, et sa dernière visite.
  final parAuteur = <String, List<SouvenirFeed>>{};
  for (final m in deProches) {
    parAuteur.putIfAbsent(m.auteurId ?? m.auteurPseudo, () => []).add(m);
  }
  final proches =
      [
        for (final MapEntry(key: id, value: ses) in parAuteur.entries)
          (
            id: id,
            pseudo: ses.first.auteurPseudo,
            photoUrl: ses.first.auteurPhotoUrl,
            fois: ses.length,
            derniere: ses
                .map((s) => s.dateVisite)
                .reduce((a, b) => a.isAfter(b) ? a : b),
            emoji: parDateDecroissante(
              ses,
            ).map((s) => s.emotion?.emoji).whereType<String>().firstOrNull,
          ),
      ]..sort(
        (a, b) => a.fois != b.fois
            ? b.fois.compareTo(a.fois)
            : b.derniere.compareTo(a.derniere),
      );
  ProcheFiche proche(SouvenirFeed m) =>
      proches.firstWhere((p) => p.id == (m.auteurId ?? m.auteurPseudo));

  final premier = duPlusAncien.where((m) => !m.estAMoi).firstOrNull;

  final impressions = <String, int>{};
  for (final m in moments) {
    for (final i in m.impressions) {
      final libelle = impressionLisible(i);
      impressions[libelle] = (impressions[libelle] ?? 0) + 1;
    }
  }
  final ceQuiRessort = [
    for (final MapEntry(key: libelle, value: fois) in impressions.entries)
      (libelle: libelle, fois: fois),
  ]..sort((a, b) => b.fois.compareTo(a.fois));

  final dates = [for (final m in miens) m.dateVisite]..sort();
  return ResumeFiche(
    note: noteSurCinq(ressentis),
    avis: ressentis.length,
    sansAvis: deProches.length - ressentis.length,
    emojiDominant: emojiDominant,
    connaissent: [for (final p in proches) p],
    yRetournent: [
      for (final p in proches)
        if (p.fois >= 2) p,
    ],
    premiereDecouverte: premier == null
        ? null
        : (proche: proche(premier), annee: premier.dateVisite.year),
    mesFois: miens.length,
    maPremiere: dates.firstOrNull,
    maDerniere: dates.lastOrNull,
    ceQuiRessort: ceQuiRessort.take(5).toList(),
    photoUrl: parDateDecroissante(
      moments,
    ).map((m) => m.photoUrl).whereType<String>().firstOrNull,
  );
}

/// "Assiette · Exceptionnelle" → "Assiette exceptionnelle".
String impressionLisible(String impression) {
  final parties = impression.split('·').map((p) => p.trim()).toList();
  if (parties.length < 2) return impression.trim();
  return '${parties.first} ${parties.skip(1).join(' ').toLowerCase()}';
}

/// Le temps écoulé depuis [date], en deux morceaux pour la fiche (« 16 »
/// et « mois », « 3 » et « semaines ») ; `null` pour aujourd'hui.
({String nombre, String unite})? tempsDepuis(
  DateTime date,
  DateTime maintenant,
) {
  final jour = DateTime(date.year, date.month, date.day);
  final aujourdhui = DateTime(
    maintenant.year,
    maintenant.month,
    maintenant.day,
  );
  final jours = aujourdhui.difference(jour).inDays;
  if (jours <= 0) return null;
  if (jours < 14) {
    return (nombre: '$jours', unite: jours == 1 ? 'jour' : 'jours');
  }
  if (jours < 60) return (nombre: '${jours ~/ 7}', unite: 'semaines');
  final mois =
      (aujourdhui.year - jour.year) * 12 + aujourdhui.month - jour.month;
  if (mois < 24) return (nombre: '$mois', unite: 'mois');
  return (nombre: '${mois ~/ 12}', unite: 'ans');
}

/// "Depuis janvier 2026 · dernière fois le 21 août 2026", ou "Le 18 juin
/// 2025" pour une seule fois.
String monHistoireIci(ResumeFiche r) {
  final premiere = r.maPremiere;
  final derniere = r.maDerniere;
  if (premiere == null || derniere == null) return '';
  String date(DateTime d) => '${d.day} ${nomDuMois(d.month)} ${d.year}';
  if (r.mesFois == 1) return 'Le ${date(derniere)}';
  return 'Depuis ${nomDuMois(premiere.month)} ${premiere.year} · '
      'dernière fois le ${date(derniere)}';
}

/// Les personnes d'une fiche, en bulles.
List<PersonnePresente> personnesFiche(List<ProcheFiche> proches) => [
  for (final p in proches)
    PersonnePresente(id: p.id, pseudo: p.pseudo, photoUrl: p.photoUrl),
];

/// Une carte de l'éventail : un proche, textes prêts à afficher.
typedef CarteProche = ({
  String id,
  String pseudo,
  String? photoUrl,

  /// Son ressenti de la dernière visite ("😍"), `null` sans ressenti.
  String? ressenti,

  /// "1 fois", "3 fois".
  String fois,

  /// "Aujourd'hui", "Hier", "Il y a 2 mois".
  String derniereVisite,
});

/// L'éventail d'une fiche : les cartes montrées, et la pastille « +N » qui
/// remplace les proches suivants (`null` : tous sont là).
typedef EventailProches = ({
  List<CarteProche> cartes,
  ({String texte, bool nombreux})? autres,
});

/// Au plus [maxCartesSansPlus] proches : une carte chacun ; au-delà, trois
/// cartes et « +min(n − 3, 10) » ([nombreux] : plus de 10 autres, la
/// pastille se dore).
const maxCartesSansPlus = 4;
const _cartesAvecPlus = 3;

EventailProches eventailProches(
  List<ProcheFiche> proches,
  DateTime maintenant,
) {
  final montres = proches.length <= maxCartesSansPlus
      ? proches
      : proches.take(_cartesAvecPlus).toList();
  final autres = proches.length - montres.length;
  return (
    cartes: [
      for (final p in montres)
        (
          id: p.id,
          pseudo: p.pseudo,
          photoUrl: p.photoUrl,
          ressenti: p.emoji,
          fois: '${p.fois} fois',
          derniereVisite: derniereVisiteLisible(p.derniere, maintenant),
        ),
    ],
    autres: autres <= 0
        ? null
        : (texte: '+${math.min(autres, 10)}', nombreux: autres > 10),
  );
}

/// "Aujourd'hui", "Hier", "Il y a 3 semaines", "Il y a 2 ans".
String derniereVisiteLisible(DateTime date, DateTime maintenant) {
  final temps = tempsDepuis(date, maintenant);
  if (temps == null) return "Aujourd'hui";
  if (temps.nombre == '1' && temps.unite == 'jour') return 'Hier';
  return 'Il y a ${temps.nombre} ${temps.unite}';
}
