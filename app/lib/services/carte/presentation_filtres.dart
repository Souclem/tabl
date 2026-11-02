import '../social/profil_public.dart';
import '../souvenirs/presentation_souvenir.dart';
import 'filtres_carte.dart';

/// "Aucune adresse", "1 adresse", "12 adresses".
String nombreAdresses(int nombre) => switch (nombre) {
  0 => 'Aucune adresse',
  1 => '1 adresse',
  _ => '$nombre adresses',
};

// Ce qu'une ligne de la feuille des filtres affiche à droite : la valeur
// choisie, ou ce que vaut l'absence de choix.

String valeurMoment(String? moment) =>
    moment == null ? 'Tous' : libelleMomentRepas(moment) ?? moment;

String valeurPeriode(PeriodeCarte periode) => periode.libelle;

/// "Toutes", "Italien", "Italien, Japonais", "Italien +2" : au-delà de
/// deux, la première et le compte des autres. Dans l'ordre de
/// [famillesCuisine].
String valeurCuisine(Set<String> familles) {
  final choisies = [
    for (final f in famillesCuisine.keys)
      if (familles.contains(f)) f,
  ];
  if (choisies.isEmpty) return 'Toutes';
  if (choisies.length <= 2) return choisies.join(', ');
  return '${choisies.first} +${choisies.length - 1}';
}

String valeurProche(String? pseudo) => pseudo ?? 'Tout le cercle';

String valeurTable(String? nom) => nom ?? 'Toutes';

String valeurHistoire(bool jamaisEssaye) =>
    jamaisEssaye ? 'Pas encore essayées' : 'Toutes';

/// Les proches dont le pseudo contient [requete], sans tenir compte des
/// majuscules ni des accents : ceux qui commencent par elle d'abord,
/// puis dans l'ordre alphabétique. [max] au plus, et combien d'autres
/// correspondent. Sans requête : les premiers dans l'ordre alphabétique.
({List<ProfilPublic> proches, int autres}) prochesCorrespondants(
  List<ProfilPublic> proches,
  String requete, {
  int max = 5,
}) {
  final q = _sansAccents(requete.trim().toLowerCase());
  final trouves = [
    for (final p in proches)
      if (_sansAccents(p.pseudo.toLowerCase()).contains(q)) p,
  ];
  int rang(ProfilPublic p) =>
      _sansAccents(p.pseudo.toLowerCase()).startsWith(q) ? 0 : 1;
  trouves.sort((a, b) {
    final ecart = rang(a) - rang(b);
    return ecart != 0
        ? ecart
        : a.pseudo.toLowerCase().compareTo(b.pseudo.toLowerCase());
  });
  return (
    proches: trouves.take(max).toList(),
    autres: trouves.length > max ? trouves.length - max : 0,
  );
}

/// Combien de lettres du début de [pseudo] correspondent à [requete]
/// (pour les souligner) ; 0 si le pseudo ne commence pas par elle.
int debutCorrespondant(String pseudo, String requete) {
  final q = _sansAccents(requete.trim().toLowerCase());
  if (q.isEmpty) return 0;
  return _sansAccents(pseudo.toLowerCase()).startsWith(q) ? q.length : 0;
}

const _avecAccents = 'àâäáãçéèêëîïíìôöóòõùûüúñÿ';
const _lettresSansAccent = 'aaaaaceeeeiiiiooooouuuuny';

String _sansAccents(String texte) => [
  for (final c in texte.split(''))
    switch (_avecAccents.indexOf(c)) {
      -1 => c,
      final i => _lettresSansAccent[i],
    },
].join();
