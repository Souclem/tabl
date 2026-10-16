import 'decouverte_table.dart';
import 'detail_proposition.dart';
import 'experience_histoire_table.dart';
import 'groupe_table.dart';
import 'message_organisation.dart';
import 'proposition_table.dart';
import 'resume_table.dart';

/// Contrat des Tables (megaprompt Bloc 3) : un espace privé orienté
/// restaurants, jamais un chat — voir "définition produit absolue",
/// règle 1. Réutilise le graphe social (`AbonnementService`) et les
/// expériences (`SouvenirService`) existants ; ne recopie jamais leurs
/// données (règle 41, 86).
abstract interface class TableService {
  /// "Vos Tables" — mes Tables où je suis membre actif, déjà triées par
  /// pertinence (règle 8 : action requise > activité utile > activité
  /// récente > dormant, jamais alphabétique).
  Future<List<ResumeTable>> mesTables();

  /// Tables où j'ai été invité mais n'ai pas encore répondu (règle 54).
  Future<List<ResumeTable>> mesInvitations();

  /// Membres actifs de chacune des [tableIds], moi exclu — pour compter
  /// qui verra une publication partagée "Seulement" avec ces Tables.
  Future<Map<String, Set<String>>> membresActifsParTable(List<String> tableIds);

  /// Crée une Table : moi-même comme premier membre actif/admin, les
  /// [membresInvitesIds] comme invités en attente (règle 50 — flow
  /// minimal, rien d'autre requis).
  Future<GroupeTable> creer({
    required String nom,
    String? emoji,
    List<String> membresInvitesIds = const [],
  });

  Future<GroupeTable> table(String tableId);

  Future<void> accepterInvitation(String tableId);
  Future<void> refuserInvitation(String tableId);

  /// Réutilise le cercle existant (règle 55) : [profilId] doit être un
  /// profil connu, pas un système d'amis parallèle.
  Future<void> inviter(String tableId, String profilId);

  Future<void> quitter(String tableId);

  /// Admin uniquement (règle 56).
  Future<void> retirerMembre(String tableId, String profilId);
  Future<void> renommer(String tableId, String nom);

  /// Supprime la Table et ses relations (memberships, associations,
  /// propositions) — ne supprime jamais les expériences sources
  /// (règle 59).
  Future<void> supprimer(String tableId);

  /// "Notre histoire" : les expériences associées, plus récentes
  /// d'abord, et la vraie récurrence détectée dedans (règle 20-21).
  Future<
    ({
      List<ExperienceHistoireTable> experiences,
      List<RecurrenceTable> laOuOnRevient,
    })
  >
  histoire(String tableId);

  /// "On y va ?" : les propositions, actives d'abord (règle 25-26).
  Future<List<PropositionTable>> propositions(String tableId);

  /// Propose un restaurant à la Table. Si une proposition active existe
  /// déjà pour ce restaurant dans cette Table, ne crée pas de doublon
  /// silencieux : retourne l'existante avec `dejaExistante: true`
  /// (règle 30).
  Future<({PropositionTable proposition, bool dejaExistante})> proposer({
    required String tableId,
    required String nomRestaurant,
    required String ville,
  });

  /// V1 : GO ou Je passe, pas de troisième option (règle 27). La
  /// disponibilité réelle (dates) est un point de raccord Bloc 4.
  Future<void> repondreProposition(String propositionId, {required bool go});

  /// "À découvrir" : vue strictement personnelle (règle 36), calculée
  /// côté service — jamais en comparant des listes côté écran.
  Future<List<DecouverteTable>> decouvertes(String tableId);

  // -- Bloc 4 : dates, disponibilités, confirmation, mini-chat --------

  /// Le détail complet d'une proposition (sondage de dates, agrégats de
  /// disponibilité, confirmation, accès au mini-chat).
  Future<DetailProposition> detailProposition(String propositionId);

  /// Creator uniquement, tant que non confirmé (règle 31) : remplace
  /// l'ensemble des dates candidates par [datesLocales] (max 7 côté
  /// écran, règle 7). Les dates retirées perdent leurs disponibilités
  /// liées (règle 31, "les disponibilités liées sont supprimées").
  Future<void> definirDatesCandidates(String propositionId, List<DateTime> datesLocales);

  /// Participant GO uniquement (règle 4), tant que non confirmé (règle
  /// 13) : remplace entièrement ma sélection précédente — 0, 1 ou
  /// plusieurs [dateCandidateIds] (règle 11, "aucune de ces dates" est
  /// une réponse valide, représentée par une liste vide).
  Future<void> soumettreDisponibilites(String propositionId, List<String> dateCandidateIds);

  /// Creator uniquement (règle 29-30) : clôture humainement le sondage.
  /// [fuseauHoraire] est stocké explicitement (règle 63), jamais
  /// redérivé du téléphone d'un lecteur.
  Future<void> confirmerDate({
    required String propositionId,
    required String dateCandidateId,
    required String fuseauHoraire,
  });

  /// Creator uniquement (règle 34-35). [heure] au format "HH:mm".
  Future<void> ajouterHeure(String propositionId, String heure);

  /// Creator uniquement (règle 52) : réouvre une nouvelle phase de dates
  /// sur la même proposition — supprime la confirmation et les
  /// anciennes dates candidates.
  Future<void> replanifier(String propositionId);

  /// Creator uniquement (règle 53).
  Future<void> annulerProposition(String propositionId);

  /// Règle 41 : accès réservé au creator et aux participants actifs
  /// ayant répondu GO — appliqué côté base (RLS), pas ici.
  Future<List<MessageOrganisation>> messagesOrganisation(String propositionId);

  /// Règle 42 : texte seul.
  Future<void> envoyerMessageOrganisation(String propositionId, String contenu);

  /// Règle 48 : l'auteur seulement.
  Future<void> supprimerMessageOrganisation(String messageId);
}
