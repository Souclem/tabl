import '../souvenirs/presentation_souvenir.dart';

/// Ce qui m'arrive, dans l'ordre où la base le dit.
enum TypeNotification {
  /// Quelqu'un demande à me suivre (profil privé).
  demandeSuivi('demande_suivi'),

  /// Quelqu'un me suit désormais.
  nouvelAbonne('nouvel_abonne'),

  /// On a accepté ma demande de suivi.
  suiviAccepte('suivi_accepte'),

  /// J'aime sur l'un de mes souvenirs.
  reaction('reaction'),

  /// Commentaire sur l'un de mes souvenirs.
  commentaire('commentaire');

  const TypeNotification(this.valeur);

  /// La valeur renvoyée par `mes_notifications()`.
  final String valeur;

  static TypeNotification? depuisValeur(String? valeur) =>
      values.where((t) => t.valeur == valeur).firstOrNull;
}

/// Une personne à l'origine d'une notification.
typedef ActeurNotification = ({String id, String pseudo, String? photoUrl});

/// Une notification telle que la base la renvoie : un seul événement.
class NotificationTabl {
  const NotificationTabl({
    required this.type,
    required this.acteur,
    required this.creeLe,
    this.souvenirId,
    this.souvenirPhotoUrl,
    this.restaurantNom,
    this.texte,
  });

  final TypeNotification type;
  final ActeurNotification acteur;
  final DateTime creeLe;
  final String? souvenirId;

  /// Déjà signée, prête à afficher.
  final String? souvenirPhotoUrl;
  final String? restaurantNom;

  /// Le commentaire.
  final String? texte;
}

/// Une ligne de l'écran des notifications : un événement, ou plusieurs
/// j'aime sur le même souvenir rassemblés (« Emma, Martin et 3 autres
/// ont aimé… »).
class LigneNotification {
  const LigneNotification({
    required this.type,
    required this.acteurs,
    required this.creeLe,
    required this.nouvelle,
    this.souvenirId,
    this.souvenirPhotoUrl,
    this.restaurantNom,
    this.texte,
  });

  final TypeNotification type;

  /// Les plus récents d'abord.
  final List<ActeurNotification> acteurs;
  final DateTime creeLe;

  /// Arrivée depuis la dernière fois que j'ai ouvert mes notifications.
  final bool nouvelle;
  final String? souvenirId;
  final String? souvenirPhotoUrl;
  final String? restaurantNom;
  final String? texte;

  ActeurNotification get acteur => acteurs.first;
}

/// Les notifications rangées pour l'écran : les demandes de suivi à
/// part, en tête (elles attendent une réponse) ; puis le reste, les j'aime
/// d'un même souvenir rassemblés, du plus récent au plus ancien. Une
/// ligne est « nouvelle » si elle est arrivée après [vuesLe].
({List<LigneNotification> demandes, List<LigneNotification> autres})
rangerNotifications(List<NotificationTabl> notifications, {DateTime? vuesLe}) {
  bool nouvelle(DateTime d) => vuesLe == null || d.isAfter(vuesLe);
  LigneNotification seule(NotificationTabl n) => LigneNotification(
    type: n.type,
    acteurs: [n.acteur],
    creeLe: n.creeLe,
    nouvelle: nouvelle(n.creeLe),
    souvenirId: n.souvenirId,
    souvenirPhotoUrl: n.souvenirPhotoUrl,
    restaurantNom: n.restaurantNom,
    texte: n.texte,
  );

  final tri = [...notifications]..sort((a, b) => b.creeLe.compareTo(a.creeLe));
  final demandes = [
    for (final n in tri)
      if (n.type == TypeNotification.demandeSuivi) seule(n),
  ];
  final autres = <LigneNotification>[];
  final jaimeParSouvenir = <String, int>{};
  for (final n in tri) {
    if (n.type == TypeNotification.demandeSuivi) continue;
    final souvenir = n.souvenirId;
    if (n.type == TypeNotification.reaction && souvenir != null) {
      final i = jaimeParSouvenir[souvenir];
      if (i != null) {
        final ligne = autres[i];
        autres[i] = LigneNotification(
          type: ligne.type,
          acteurs: [...ligne.acteurs, n.acteur],
          creeLe: ligne.creeLe,
          nouvelle: ligne.nouvelle || nouvelle(n.creeLe),
          souvenirId: ligne.souvenirId,
          souvenirPhotoUrl: ligne.souvenirPhotoUrl,
          restaurantNom: ligne.restaurantNom,
        );
        continue;
      }
      jaimeParSouvenir[souvenir] = autres.length;
    }
    autres.add(seule(n));
  }
  return (demandes: demandes, autres: autres);
}

/// Au moins une notification arrivée depuis la dernière visite : la
/// pastille de la cloche.
bool aDesNouvelles(List<NotificationTabl> notifications, {DateTime? vuesLe}) =>
    notifications.any((n) => vuesLe == null || n.creeLe.isAfter(vuesLe));

/// La phrase d'une ligne, en morceaux : les noms en gras, le reste
/// normal (« **Emma** et **Martin** ont aimé votre moment chez Bibo. »).
List<({String texte, bool gras})> phraseNotification(LigneNotification l) {
  final noms = [for (final a in l.acteurs) a.pseudo];
  final morceaux = <({String texte, bool gras})>[];
  void gras(String t) => morceaux.add((texte: t, gras: true));
  void normal(String t) => morceaux.add((texte: t, gras: false));

  // Les noms : « Emma », « Emma et Martin », « Emma, Martin et 3 autres ».
  gras(noms.first);
  if (noms.length == 2) {
    normal(' et ');
    gras(noms[1]);
  } else if (noms.length > 2) {
    normal(', ');
    gras(noms[1]);
    final autres = noms.length - 2;
    normal(' et ${pluriel(autres, 'autre')}');
  }
  final plusieurs = noms.length > 1;
  final ou = l.restaurantNom == null ? '' : ' chez ${l.restaurantNom}';
  switch (l.type) {
    case TypeNotification.demandeSuivi:
      normal(' souhaite vous suivre.');
    case TypeNotification.nouvelAbonne:
      normal(' vous suit désormais.');
    case TypeNotification.suiviAccepte:
      normal(' a accepté votre demande de suivi.');
    case TypeNotification.reaction:
      normal(
        plusieurs ? ' ont aimé votre moment$ou.' : ' a aimé votre moment$ou.',
      );
    case TypeNotification.commentaire:
      final texte = l.texte?.trim();
      normal(' a commenté votre moment$ou');
      normal(texte == null || texte.isEmpty ? '.' : ' : « $texte »');
  }
  return morceaux;
}
