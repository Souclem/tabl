import '../restaurants/categories_lieu.dart';
import '../social/profil_public.dart';
import 'precompletion_souvenir.dart';

/// Le repas qu'on dit avoir fait quand l'heure de la prise ne dit rien de
/// sûr (« Où et quand ») : le matin à 8 h 30, midi à 12 h 30, le soir à
/// 20 h.
const _heureMatin = (heure: 8, minute: 30);
const _heureMidi = (heure: 12, minute: 30);
const _heureSoir = (heure: 20, minute: 0);

/// Le moment stocké (`matin` / `midi` / `soir`) d'un moment en création.
String momentDuBrouillon(DateTime priseLe) => momentDuJour(priseLe);

/// L'heure de repas à garder quand on choisit [moment] : inchangée si la
/// prise est déjà de ce moment, sinon le même jour à l'heure habituelle du
/// repas.
DateTime priseLePourMoment(DateTime priseLe, String moment) {
  if (momentDuBrouillon(priseLe) == moment) return priseLe;
  final heure = switch (moment) {
    'matin' => _heureMatin,
    'midi' => _heureMidi,
    _ => _heureSoir,
  };
  return DateTime(
    priseLe.year,
    priseLe.month,
    priseLe.day,
    heure.heure,
    heure.minute,
  );
}

/// Les personnes dont le pseudo contient [texte] (sans accent ni casse) ;
/// toutes si [texte] est vide.
List<ProfilPublic> filtrerPersonnes(
  List<ProfilPublic> personnes,
  String texte,
) {
  final cherche = normaliserPourRecherche(texte.trim());
  if (cherche.isEmpty) return personnes;
  return [
    for (final p in personnes)
      if (normaliserPourRecherche(p.pseudo).contains(cherche)) p,
  ];
}

/// « Chez qui ? » dans « Où et quand » : les personnes que je suis,
/// celles qui étaient à table ([prioritairesIds]) d'abord, puis par
/// pseudo. Sans recherche, [max] au plus (`null` : toutes), plus celle
/// déjà choisie ([choisieId]) si elle n'y est pas ; avec, toutes celles
/// qui correspondent.
List<ProfilPublic> personnesChezQui(
  List<ProfilPublic> suivis, {
  String recherche = '',
  Set<String> prioritairesIds = const {},
  String? choisieId,
  int? max,
}) {
  final triees = [...filtrerPersonnes(suivis, recherche)]
    ..sort((a, b) {
      final avant =
          (prioritairesIds.contains(a.id) ? 0 : 1) -
          (prioritairesIds.contains(b.id) ? 0 : 1);
      if (avant != 0) return avant;
      return normaliserPourRecherche(
        a.pseudo,
      ).compareTo(normaliserPourRecherche(b.pseudo));
    });
  if (max == null || recherche.trim().isNotEmpty || triees.length <= max) {
    return triees;
  }
  final premieres = triees.take(max).toList();
  final choisie = triees.where((p) => p.id == choisieId).firstOrNull;
  if (choisie != null && !premieres.contains(choisie)) premieres.add(choisie);
  return premieres;
}
