import '../restaurants/lieu_restaurant.dart';
import 'brouillon_local.dart';

/// Un brouillon pas encore publié rappelle à son auteur de le terminer :
/// 2 h, puis 5 h après sa dernière modification. Les rappels ne sonnent
/// que l'app fermée ou en arrière-plan (voir [ReprisePublications]).
const delaisRappelsBrouillon = [Duration(hours: 2), Duration(hours: 5)];

/// Le type des notifications de rappel, quand on en touche une.
const typeNotificationBrouillon = 'brouillon';

/// Une notification locale à programmer sur le téléphone, [dans] ce délai.
typedef RappelBrouillon = ({
  String identifiant,
  String brouillonId,
  Duration dans,
  String titre,
  String corps,
});

/// L'identifiant d'un rappel sur le téléphone : un par brouillon et par
/// délai, pour qu'un rappel reprogrammé remplace l'ancien.
String identifiantRappel(String brouillonId, int rang) =>
    'brouillon-$brouillonId-$rang';

/// Les identifiants de tous les rappels possibles d'un brouillon.
List<String> identifiantsRappels(String brouillonId) => [
  for (var rang = 0; rang < delaisRappelsBrouillon.length; rang++)
    identifiantRappel(brouillonId, rang),
];

/// Les rappels encore à venir pour ces brouillons à reprendre (ceux que
/// « + » propose, voir `brouillonsAReprendre`) : un brouillon modifié il y
/// a plus de 5 h n'en a plus.
List<RappelBrouillon> rappelsBrouillons(
  List<Brouillon> aReprendre, {
  required DateTime maintenant,
}) => [
  for (final b in aReprendre)
    for (var rang = 0; rang < delaisRappelsBrouillon.length; rang++)
      if (b.modifieLe.add(delaisRappelsBrouillon[rang]).difference(maintenant)
          case final dans when dans > Duration.zero)
        (
          identifiant: identifiantRappel(b.id, rang),
          brouillonId: b.id,
          dans: dans,
          titre: titreRappelBrouillon(b),
          corps: corpsRappelBrouillon(rang),
        ),
];

/// « Votre moment chez Le Comptoir », « Votre moment chez vous », ou
/// « Votre moment vous attend » sans lieu choisi (ou pour un
/// pique-nique).
String titreRappelBrouillon(Brouillon brouillon) {
  final lieu = brouillon.lieu;
  final chez = lieu == null
      ? null
      : chezDansUnePhrase(lieu.libelle, lieu.genre.enBase);
  return chez == null ? 'Votre moment vous attend' : 'Votre moment $chez';
}

/// Le premier rappel, puis le second.
String corpsRappelBrouillon(int rang) => rang == 0
    ? 'Il n\'est pas encore publié : quelques touches et c\'est fait.'
    : 'Toujours en brouillon. Publiez-le tant que le souvenir est frais.';

/// Les notifications locales du téléphone (sur iPhone : `AppDelegate.swift`).
abstract interface class RappelsSysteme {
  /// Remplace tous les rappels de brouillon programmés par [rappels]
  /// (vide : plus aucun).
  Future<void> remplacer(List<RappelBrouillon> rappels);

  /// Retire les rappels de ce brouillon : publié, supprimé ou confié à la
  /// file d'envoi.
  Future<void> annuler(String brouillonId);
}
