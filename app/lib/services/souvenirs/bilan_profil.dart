import '../restaurants/categories_lieu.dart';
import 'journal_profil.dart';
import 'personne_presente.dart';
import 'presentation_souvenir.dart';
import 'souvenir_feed.dart';

/// Une personne du bilan : avec qui on partage le plus de tables.
class ProcheBilan {
  const ProcheBilan({
    required this.personne,
    required this.nom,
    required this.detail,
  });

  final PersonnePresente personne;

  /// "Arthur", ou "Toi".
  final String nom;

  /// "5 moments · 4 adresses" pour le binôme, "4 moments" pour les autres.
  final String detail;
}

/// Une adresse où l'on est revenu dans l'année.
class RetourBilan {
  const RetourBilan({
    required this.restaurantNom,
    required this.lieu,
    required this.photoUrl,
    required this.nombreVisites,
    required this.total,
  });

  final String restaurantNom;

  /// "Milan · depuis novembre 2025".
  final String lieu;

  /// La photo de la dernière visite.
  final String? photoUrl;

  /// Visites dans l'année.
  final int nombreVisites;

  /// "3 visites au total".
  final String total;
}

/// Une ville du bilan, avec sa part par rapport à la plus fréquentée.
class VilleBilan {
  const VilleBilan({
    required this.nom,
    required this.compte,
    required this.part,
  });

  final String nom;

  /// "6 moments".
  final String compte;

  /// De 0 à 1 : 1 pour la ville la plus fréquentée.
  final double part;
}

/// Déjeuner ou dîner, et sa part de l'année.
class PartMoment {
  const PartMoment({
    required this.libelle,
    required this.detail,
    required this.part,
  });

  /// "Dîner".
  final String libelle;

  /// "8 · 67 %".
  final String detail;

  /// De 0 à 1.
  final double part;
}

/// Les titres du bilan : « tu » sur le sien, le prénom sur celui d'un
/// autre.
class TitresBilan {
  const TitresBilan({
    required this.avecQui,
    required this.retours,
    required this.villes,
    required this.moments,
    required this.cuisines,
    required this.aucunRetour,
    required this.pied,
  });

  final String avecQui;
  final String retours;
  final String villes;
  final String moments;
  final String cuisines;
  final String aucunRetour;
  final String pied;
}

/// Un profil en chiffres, depuis le début ou sur une année : avec qui,
/// où, quand, quoi.
class BilanAnnee {
  const BilanAnnee({
    required this.titre,
    required this.resume,
    required this.titres,
    required this.nombreMoments,
    required this.binome,
    required this.roleBinome,
    required this.autresProches,
    required this.retours,
    required this.villes,
    required this.moments,
    required this.cuisines,
  });

  /// "Ton bilan", "Ton 2026", "Le 2026 d'Arthur".
  final String titre;

  /// "12 moments · 10 adresses · 4 villes".
  final String resume;
  final TitresBilan titres;
  final int nombreMoments;

  /// La personne la plus présente de l'année, `null` si toujours en solo.
  final ProcheBilan? binome;

  /// "Ton binôme de table".
  final String roleBinome;

  /// Les suivantes, 3 au plus.
  final List<ProcheBilan> autresProches;
  final List<RetourBilan> retours;
  final List<VilleBilan> villes;
  final List<PartMoment> moments;

  /// "Italien · 3", de la cuisine la plus fréquente à la moins fréquente.
  final List<String> cuisines;
}

/// Le bilan d'un profil à partir de tous ses moments : depuis le début,
/// ou sur [annee] seulement. [prenom] : `null` pour son propre profil,
/// le pseudo de l'autre sinon.
BilanAnnee bilanDuProfil(
  List<SouvenirFeed> tous, {
  int? annee,
  String? prenom,
}) {
  final estMoi = prenom == null;
  final souvenirs = [
    for (final s in parDateDecroissante(tous))
      if (annee == null || s.dateVisite.year == annee) s,
  ];
  final periode = annee == null ? '' : ' cette année';

  final adresses = {for (final s in souvenirs) cleRestaurant(s)}.length;
  final nombreVilles = {
    for (final s in souvenirs)
      if (s.ville.isNotEmpty) s.ville,
  }.length;

  final personnes = personnesLesPlusPresentes(souvenirs);
  ProcheBilan proche(PersonnePresente p, {required bool detaille}) {
    final avecElle = [
      for (final s in souvenirs)
        if (s.presents.any((x) => x.id == p.id)) s,
    ];
    final moments = pluriel(avecElle.length, 'moment');
    final lieux = {for (final s in avecElle) cleRestaurant(s)}.length;
    return ProcheBilan(
      personne: p,
      nom: nomPersonne(p),
      detail: detaille ? '$moments · ${pluriel(lieux, 'adresse')}' : moments,
    );
  }

  final binome = personnes.isEmpty
      ? null
      : proche(personnes.first, detaille: true);

  return BilanAnnee(
    titre: switch ((estMoi, annee)) {
      (true, null) => 'Ton bilan',
      (true, _) => 'Ton $annee',
      (false, null) => 'Le bilan ${_de(prenom!)}',
      (false, _) => 'Le $annee ${_de(prenom!)}',
    },
    resume:
        '${pluriel(souvenirs.length, 'moment')} · '
        '${pluriel(adresses, 'adresse')} · ${pluriel(nombreVilles, 'ville')}',
    titres: estMoi
        ? TitresBilan(
            avecQui: 'Avec qui tu partages tes tables',
            retours: 'Là où tu reviens',
            villes: 'Tes villes',
            moments: 'Tes moments',
            cuisines: 'Ce que tu manges',
            aucunRetour: 'Aucune adresse deux fois$periode… pour l’instant.',
            pied: 'Ton bilan se construit tout seul, à chaque moment publié.',
          )
        : TitresBilan(
            avecQui: 'Avec qui $prenom partage ses tables',
            retours: 'Là où $prenom revient',
            villes: 'Ses villes',
            moments: 'Ses moments',
            cuisines: 'Ce qu’aime $prenom',
            aucunRetour: 'Pas encore d’adresse où revenir$periode.',
            pied:
                'Seuls les moments que $prenom partage avec toi comptent '
                'ici.',
          ),
    nombreMoments: souvenirs.length,
    binome: binome,
    roleBinome: estMoi
        ? 'Ton binôme de table'
        : (binome?.personne.estMoi ?? false)
        ? 'Son binôme de table : toi'
        : 'Son binôme de table',
    autresProches: [
      for (final p in personnes.skip(1).take(3)) proche(p, detaille: false),
    ],
    retours: _retours(souvenirs, tous),
    villes: _villes(souvenirs),
    moments: _moments(souvenirs),
    cuisines: _cuisines(souvenirs),
  );
}

List<RetourBilan> _retours(
  List<SouvenirFeed> deLAnnee,
  List<SouvenirFeed> tous,
) {
  final parRestaurant = <String, List<SouvenirFeed>>{};
  for (final s in deLAnnee) {
    parRestaurant.putIfAbsent(cleRestaurant(s), () => []).add(s);
  }
  final revenus = [
    for (final MapEntry(:key, :value) in parRestaurant.entries)
      if (value.length >= 2) (cle: key, visites: value),
  ];
  // À égalité, l'ordre d'insertion (le plus récent d'abord) départage.
  final rang = {for (var i = 0; i < revenus.length; i++) revenus[i].cle: i};
  revenus.sort((a, b) {
    final ecart = b.visites.length.compareTo(a.visites.length);
    return ecart != 0 ? ecart : rang[a.cle]!.compareTo(rang[b.cle]!);
  });
  return [for (final r in revenus) _retour(r.visites, tous)];
}

RetourBilan _retour(List<SouvenirFeed> visitesAnnee, List<SouvenirFeed> tous) {
  final derniere = visitesAnnee.first;
  final cle = cleRestaurant(derniere);
  final toutes = parDateDecroissante([
    for (final s in tous)
      if (cleRestaurant(s) == cle) s,
  ]);
  final premiere = toutes.last.dateVisite;
  final depuis = 'depuis ${nomDuMois(premiere.month)} ${premiere.year}';
  return RetourBilan(
    restaurantNom: derniere.restaurantNom,
    lieu: derniere.ville.isEmpty ? depuis : '${derniere.ville} · $depuis',
    photoUrl: derniere.photoUrl,
    nombreVisites: visitesAnnee.length,
    total: '${pluriel(toutes.length, 'visite')} au total',
  );
}

List<VilleBilan> _villes(List<SouvenirFeed> souvenirs) {
  final nombre = <String, int>{};
  for (final s in souvenirs) {
    if (s.ville.isEmpty) continue;
    nombre[s.ville] = (nombre[s.ville] ?? 0) + 1;
  }
  final villes = nombre.keys.toList();
  final rang = {for (var i = 0; i < villes.length; i++) villes[i]: i};
  villes.sort((a, b) {
    final ecart = nombre[b]!.compareTo(nombre[a]!);
    return ecart != 0 ? ecart : rang[a]!.compareTo(rang[b]!);
  });
  if (villes.isEmpty) return const [];
  final max = nombre[villes.first]!;
  return [
    for (final v in villes)
      VilleBilan(
        nom: v,
        compte: pluriel(nombre[v]!, 'moment'),
        part: nombre[v]! / max,
      ),
  ];
}

/// `moment` vaut `'matin'`, `'midi'` ou `'soir'` en base.
List<PartMoment> _moments(List<SouvenirFeed> souvenirs) {
  final total = souvenirs.length;
  if (total == 0) return const [];
  return [
    for (final code in momentsRepas.reversed)
      if (souvenirs.where((s) => s.moment == code).length case final n
          when n > 0)
        PartMoment(
          libelle: libelleMomentRepas(code)!,
          detail: '$n · ${(n / total * 100).round()} %',
          part: n / total,
        ),
  ];
}

/// Les catégories trop générales ("Restaurant") ne disent rien de ce
/// qu'on a mangé : la première plus précise compte.
List<String> _cuisines(List<SouvenirFeed> souvenirs) {
  const generales = {'Restaurant', 'Bar', 'Café', 'Food Court'};
  final nombre = <String, int>{};
  for (final s in souvenirs) {
    final categorie = s.categories.where((c) => !generales.contains(c));
    if (categorie.isEmpty) continue;
    final libelle = libelleCategorie(categorie.first);
    nombre[libelle] = (nombre[libelle] ?? 0) + 1;
  }
  final cuisines = nombre.keys.toList();
  final rang = {for (var i = 0; i < cuisines.length; i++) cuisines[i]: i};
  cuisines.sort((a, b) {
    final ecart = nombre[b]!.compareTo(nombre[a]!);
    return ecart != 0 ? ecart : rang[a]!.compareTo(rang[b]!);
  });
  return [for (final c in cuisines.take(6)) '$c · ${nombre[c]}'];
}

/// "d'Arthur", "de Louise".
String _de(String prenom) =>
    RegExp(r'^[aeiouyhâàéèêëîïôûAEIOUYHÂÀÉÈÊËÎÏÔÛ]').hasMatch(prenom)
    ? 'd’$prenom'
    : 'de $prenom';
