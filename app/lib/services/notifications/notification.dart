import '../avis/avis.dart';
import '../restaurants/lieu_restaurant.dart';
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
  commentaire('commentaire'),

  /// Réponse à l'un de mes commentaires.
  reponseCommentaire('reponse'),

  /// J'aime sur l'un de mes commentaires.
  reactionCommentaire('reaction_commentaire'),

  /// On me demande mon avis sur un restaurant (pas encore répondu).
  demandeAvis('demande_avis'),

  /// On a répondu à ma demande d'avis.
  avisRecu('avis_recu'),

  /// On a publié un moment chez moi (je suis cité, jamais localisé).
  chezVous('chez_vous');

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
    this.restaurantId,
    this.restaurantNom,
    this.texte,
    this.reponse,
    this.demandeId,
    this.commentaireId,
    this.restaurantGenre,
  });

  final TypeNotification type;
  final ActeurNotification acteur;
  final DateTime creeLe;
  final String? souvenirId;
  final String? restaurantId;

  /// Une réponse à ma demande d'avis.
  final ReponseAvis? reponse;

  /// La demande d'avis concernée.
  final String? demandeId;

  /// Le commentaire concerné (écrit, ou aimé).
  final String? commentaireId;

  /// Déjà signée, prête à afficher.
  final String? souvenirPhotoUrl;
  final String? restaurantNom;

  /// `restaurants.genre` : « domicile », « chez », « ailleurs », ou rien
  /// pour un restaurant.
  final String? restaurantGenre;

  /// Le commentaire, la question posée, ou le mot de la réponse.
  final String? texte;
}

/// Une ligne de l'écran des notifications : un événement, ou plusieurs
/// j'aime sur le même souvenir (ou le même commentaire) rassemblés
/// (« Emma, Martin et 3 autres ont aimé… »).
class LigneNotification {
  const LigneNotification({
    required this.type,
    required this.acteurs,
    required this.creeLe,
    required this.nouvelle,
    this.souvenirId,
    this.souvenirPhotoUrl,
    this.restaurantId,
    this.restaurantNom,
    this.texte,
    this.reponse,
    this.demandeId,
    this.restaurantGenre,
  });

  final TypeNotification type;

  /// Les plus récents d'abord.
  final List<ActeurNotification> acteurs;
  final DateTime creeLe;

  /// Arrivée depuis la dernière fois que j'ai ouvert mes notifications.
  final bool nouvelle;
  final String? souvenirId;
  final String? souvenirPhotoUrl;
  final String? restaurantId;
  final String? restaurantNom;
  final String? restaurantGenre;
  final String? texte;
  final ReponseAvis? reponse;
  final String? demandeId;

  ActeurNotification get acteur => acteurs.first;
}

/// Les notifications rangées pour l'écran : les demandes (de suivi,
/// d'avis) à part, en tête (elles attendent une réponse) ; puis le reste,
/// les j'aime d'un même souvenir — ou d'un même commentaire —
/// rassemblés, du plus récent au plus ancien. Une ligne est « nouvelle »
/// si elle est arrivée après [vuesLe].
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
    restaurantId: n.restaurantId,
    restaurantNom: n.restaurantNom,
    restaurantGenre: n.restaurantGenre,
    texte: n.texte,
    reponse: n.reponse,
    demandeId: n.demandeId,
  );

  final tri = [...notifications]..sort((a, b) => b.creeLe.compareTo(a.creeLe));
  bool attend(NotificationTabl n) =>
      n.type == TypeNotification.demandeSuivi ||
      n.type == TypeNotification.demandeAvis;
  final demandes = [
    for (final n in tri)
      if (attend(n)) seule(n),
  ];
  // Ce que des j'aime ont en commun : le même souvenir, ou le même
  // commentaire.
  String? cible(NotificationTabl n) => switch (n.type) {
    TypeNotification.reaction when n.souvenirId != null =>
      'souvenir:${n.souvenirId}',
    TypeNotification.reactionCommentaire when n.commentaireId != null =>
      'commentaire:${n.commentaireId}',
    _ => null,
  };
  final autres = <LigneNotification>[];
  final jaimeParCible = <String, int>{};
  for (final n in tri) {
    if (attend(n)) continue;
    final cle = cible(n);
    if (cle != null) {
      final i = jaimeParCible[cle];
      if (i != null) {
        final ligne = autres[i];
        autres[i] = LigneNotification(
          type: ligne.type,
          acteurs: [...ligne.acteurs, n.acteur],
          creeLe: ligne.creeLe,
          nouvelle: ligne.nouvelle || nouvelle(n.creeLe),
          souvenirId: ligne.souvenirId,
          souvenirPhotoUrl: ligne.souvenirPhotoUrl,
          restaurantId: ligne.restaurantId,
          restaurantNom: ligne.restaurantNom,
          restaurantGenre: ligne.restaurantGenre,
          texte: ligne.texte,
        );
        continue;
      }
      jaimeParCible[cle] = autres.length;
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
  // « chez Bibo », « chez vous » (mon moment chez moi), rien pour un
  // pique-nique.
  final chez = chezDansUnePhrase(l.restaurantNom, l.restaurantGenre);
  final ou = chez == null ? '' : ' $chez';
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
    case TypeNotification.reponseCommentaire:
      final texte = l.texte?.trim();
      normal(' a répondu à votre commentaire');
      normal(texte == null || texte.isEmpty ? '.' : ' : « $texte »');
    case TypeNotification.reactionCommentaire:
      final texte = l.texte?.trim();
      normal(
        plusieurs ? ' ont aimé votre commentaire' : ' a aimé votre commentaire',
      );
      normal(texte == null || texte.isEmpty ? '.' : ' : « $texte »');
    case TypeNotification.demandeAvis:
      final texte = l.texte?.trim();
      normal(' vous demande votre avis$ou');
      normal(texte == null || texte.isEmpty ? '.' : ' : « $texte »');
    case TypeNotification.avisRecu:
      final reponse = l.reponse;
      final mot = l.texte?.trim();
      normal(' a répondu$ou : ');
      gras(reponse == null ? 'Réponse' : '${reponse.emoji} ${reponse.libelle}');
      if (mot != null && mot.isNotEmpty) normal(' — « $mot »');
    case TypeNotification.chezVous:
      normal(' a publié un moment chez vous.');
  }
  return morceaux;
}
