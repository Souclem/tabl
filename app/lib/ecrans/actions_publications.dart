import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_profil_autre.dart';
import 'ecran_publier.dart';
import 'feuille_audience.dart';
import 'feuille_commentaires.dart';
import 'feuille_restaurant.dart';

/// Ce que partagent tous les écrans qui affichent une liste de
/// publications (Feed, profils) : la liste chargée, la réaction
/// optimiste, l'ouverture des commentaires, et la traduction d'un
/// [SouvenirFeed] en [TablPublication] prête à afficher.
mixin ActionsPublications<T extends StatefulWidget> on State<T> {
  SouvenirService get souvenirService;

  /// Pour ouvrir le profil d'un auteur ; `null` (par défaut) : les
  /// auteurs ne sont pas touchables, et ses propres publications n'ont
  /// pas de menu « ⋯ ».
  AbonnementService? get abonnementService => null;

  /// Pour « Qui peut voir » et « Modifier » ; `null` (par défaut) :
  /// construits à la demande.
  TableService? get tableService => null;
  RechercheLieuService? get rechercheLieuService => null;
  PositionService? get positionService => null;

  /// La publication dépliée sur place (une seule à la fois), voir
  /// [publicationDepliable].
  String? publicationOuverte;

  /// `null` tant que le premier chargement n'est pas terminé. Mutable :
  /// une réaction met à jour la liste en place, sans tout recharger.
  List<SouvenirFeed>? souvenirs;

  /// Relance le chargement complet de la liste — appelé au retour d'une
  /// page (restaurant, profil) où ce qui est visible a pu changer.
  void recharger();

  Future<void> basculerReaction(SouvenirFeed souvenir) async {
    final nouvelEtat = !souvenir.jaiReagi;
    // Optimiste : l'animation et le compteur réagissent tout de suite,
    // sans attendre le réseau — on ne fait pas patienter pour un geste
    // aussi léger.
    remplacer(
      souvenir.copierAvec(
        jaiReagi: nouvelEtat,
        nombreReactions: souvenir.nombreReactions + (nouvelEtat ? 1 : -1),
      ),
    );
    try {
      await souvenirService.basculerReaction(souvenir.id, reagir: nouvelEtat);
    } catch (_) {
      // Échec réseau : on revient à l'état d'avant plutôt que de laisser
      // affiché quelque chose qui n'a pas vraiment été enregistré.
      if (!mounted) return;
      remplacer(souvenir);
      afficherMessage(context, messageErreurGenerique);
    }
  }

  /// "Enregistrer" : ajoute le restaurant à mes envies (ou l'en retire).
  /// Optimiste, comme la réaction ; tous les posts du même restaurant
  /// changent ensemble, puisque l'envie porte sur le lieu.
  Future<void> basculerEnvie(SouvenirFeed souvenir) async {
    final restaurantId = souvenir.restaurantId;
    if (restaurantId == null) return;
    final envie = !souvenir.estEnvie;
    _marquerEnvie(restaurantId, envie);
    try {
      await souvenirService.basculerEnvie(restaurantId, envie: envie);
    } catch (_) {
      if (!mounted) return;
      _marquerEnvie(restaurantId, !envie);
      afficherMessage(context, messageErreurGenerique);
    }
  }

  void _marquerEnvie(String restaurantId, bool envie) {
    final actuels = souvenirs;
    if (actuels == null) return;
    setState(() {
      souvenirs = [
        for (final s in actuels)
          s.restaurantId == restaurantId ? s.copierAvec(estEnvie: envie) : s,
      ];
    });
  }

  /// Les commentaires, dans une feuille par-dessus la liste : on reste
  /// à sa place dans le Feed, et le moment suit leur nombre.
  Future<void> ouvrirCommentaires(SouvenirFeed souvenir) {
    return ouvrirFeuilleCommentaires(
      context,
      souvenirService: souvenirService,
      souvenir: souvenir,
      onOuvrirProfil: abonnementService == null ? null : ouvrirProfilDe,
      onNombre: (nombre) {
        final actuel = souvenirs?.where((s) => s.id == souvenir.id).firstOrNull;
        if (actuel == null || actuel.nombreCommentaires == nombre) return;
        remplacer(actuel.copierAvec(nombreCommentaires: nombre));
      },
    );
  }

  /// La page du restaurant d'une publication, en feuille par-dessus
  /// l'écran ; à sa fermeture, la liste est rechargée (une envie, une
  /// réaction ont pu changer).
  Future<void> ouvrirRestaurant(SouvenirFeed souvenir) async {
    // Un lieu personnel n'a pas de page : ni adresse, ni avis à lire.
    if (souvenir.lieuPersonnel) return;
    await ouvrirFeuilleRestaurant(
      context,
      nom: souvenir.restaurantNom,
      sousTitre: souvenir.ville,
      restaurantId: souvenir.restaurantId,
      estEnvie: souvenir.estEnvie,
      souvenirService: souvenirService,
      abonnementService: abonnementService,
    );
    if (!mounted) return;
    recharger();
  }

  /// Le profil de l'auteur d'une publication.
  Future<void> ouvrirProfil(SouvenirFeed souvenir) async {
    final auteurId = souvenir.auteurId;
    if (auteurId == null) return;
    await ouvrirProfilDe(auteurId, souvenir.auteurPseudo);
  }

  /// Le profil de quelqu'un, en page ; à son retour, la liste est
  /// rechargée (un abonnement a pu changer ce qui est visible).
  Future<void> ouvrirProfilDe(String profilId, String pseudo) async {
    final service = abonnementService;
    if (service == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranProfilAutre(
          profilId: profilId,
          pseudo: pseudo,
          abonnementService: service,
          souvenirService: souvenirService,
        ),
      ),
    );
    if (!mounted) return;
    recharger();
  }

  /// Une publication en ligne compacte, qui se déplie sur place en
  /// publication complète au tap (page d'un restaurant, profils). La
  /// ligne compacte montre ce qui varie sur la page : l'auteur sur un
  /// restaurant ([titreAuteur]), le restaurant sur un profil.
  Widget publicationDepliable(
    SouvenirFeed souvenir, {
    required ContextePublication contexte,
    bool titreAuteur = false,
    VoidCallback? onOuvrirLieu,
    VoidCallback? onOptions,
  }) {
    return TablPublicationDepliable(
      key: ValueKey(souvenir.id),
      ouvert: publicationOuverte == souvenir.id,
      photoUrl: souvenir.photoUrl,
      compact: TablLigneAvis(
        titre: titreAuteur ? souvenir.auteurPseudo : souvenir.restaurantNom,
        avatarPseudo: titreAuteur ? souvenir.auteurPseudo : null,
        avatarPhotoUrl: titreAuteur ? souvenir.auteurPhotoUrl : null,
        dateLisible: dateLisibleSouvenir(
          souvenir.dateVisite,
          jourConnu: souvenir.jourConnu,
        ),
        photoUrl: souvenir.photoUrl,
        emoji: souvenir.emotion?.emoji,
        legende: legendeAffichee(souvenir.legende),
        resumeReactions: souvenir.nombreReactions == 0
            ? null
            : libelleReactionsSouvenir(souvenir),
        onPresse: () => setState(() => publicationOuverte = souvenir.id),
      ),
      complet: construirePublication(
        souvenir,
        contexte: contexte,
        onOuvrirLieu: onOuvrirLieu ?? () => ouvrirRestaurant(souvenir),
        onOptions: onOptions,
      ),
      onReduire: () => setState(() => publicationOuverte = null),
    );
  }

  /// Le menu « ⋯ » de l'une de mes publications : la modifier (un
  /// moment), choisir qui la voit, la supprimer.
  void optionsPublication(SouvenirFeed souvenir) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: TablCouleurs.of(context).surface,
      builder: (contexteFeuille) {
        final erreur = TablCouleurs.of(contexteFeuille).erreur;
        void choisir(Future<void> Function(SouvenirFeed) action) {
          Navigator.of(contexteFeuille).pop();
          action(souvenir);
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Un souvenir se range par sa date : il a son propre écran,
              // pas encore modifiable.
              if (!souvenir.estSouvenir)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Modifier'),
                  onTap: () => choisir(modifierPublication),
                ),
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Qui peut voir'),
                onTap: () => choisir(modifierAudience),
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: erreur),
                title: Text('Supprimer', style: TextStyle(color: erreur)),
                onTap: () => choisir(supprimerPublication),
              ),
            ],
          ),
        );
      },
    );
  }

  TableService get _tables =>
      tableService ?? TableServiceSupabase(TablBackend.client);

  /// Le moment s'ouvre dans l'écran qui l'a publié, prérempli.
  Future<void> modifierPublication(SouvenirFeed souvenir) async {
    final abonnements = abonnementService;
    if (abonnements == null) return;
    final modifie = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EcranPublier(
          souvenirService: souvenirService,
          abonnementService: abonnements,
          tableService: _tables,
          rechercheLieuService:
              rechercheLieuService ??
              RechercheLieuServiceSupabase(TablBackend.client),
          positionService: positionService ?? PositionServiceGeolocator(),
          aModifier: souvenir,
        ),
      ),
    );
    if (modifie != true || !mounted) return;
    _revenirIci();
    recharger();
    afficherMessage(context, 'Moment modifié.');
  }

  Future<void> modifierAudience(SouvenirFeed souvenir) async {
    final abonnements = abonnementService;
    if (abonnements == null) return;
    final ({AudienceSouvenir audience, Set<String> amisTaguesIds}) actuelle;
    try {
      actuelle = await souvenirService.audienceActuelle(souvenir.id);
    } catch (_) {
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
      return;
    }
    if (!mounted) return;
    final choisie = await ouvrirFeuilleAudience(
      context,
      audienceInitiale: actuelle.audience,
      abonnementService: abonnements,
      tableService: _tables,
      amisTaguesIds: actuelle.amisTaguesIds,
    );
    if (choisie == null || !mounted) return;
    try {
      final tablesEnEchec = await souvenirService.modifierAudience(
        souvenir.id,
        choisie,
      );
      if (!mounted) return;
      afficherMessage(
        context,
        tablesEnEchec.isEmpty
            ? 'Audience mise à jour.'
            : 'Mise à jour, mais impossible de partager avec '
                  '${pluriel(tablesEnEchec.length, 'Table')}.',
      );
      recharger();
    } catch (_) {
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    }
  }

  /// Après confirmation : c'est définitif.
  Future<void> supprimerPublication(SouvenirFeed souvenir) async {
    final quoi = souvenir.estSouvenir ? 'ce souvenir' : 'ce moment';
    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexteDialogue) => AlertDialog(
        backgroundColor: TablTokens.surface,
        title: Text('Supprimer $quoi ?'),
        content: const Text(
          'Il disparaîtra de votre profil, avec ses photos, ses réactions '
          'et ses commentaires. C\'est définitif.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexteDialogue).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexteDialogue).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: TablTokens.erreur),
            ),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    try {
      await souvenirService.supprimer(souvenir.id);
    } catch (e) {
      debugPrint('ActionsPublications: suppression : $e');
      if (mounted) afficherMessage(context, messageErreurGenerique);
      return;
    }
    if (!mounted) return;
    _revenirIci();
    recharger();
    afficherMessage(
      context,
      souvenir.estSouvenir ? 'Souvenir supprimé.' : 'Moment supprimé.',
    );
  }

  /// Le moment agrandi, s'il était ouvert par-dessus, n'est plus à jour :
  /// on revient sur cet écran.
  void _revenirIci() {
    final ici = ModalRoute.of(context);
    Navigator.of(context).popUntil((route) => ici == null || route == ici);
  }

  void remplacer(SouvenirFeed souvenir) {
    final actuels = souvenirs;
    if (actuels == null) return;
    setState(() {
      souvenirs = [
        for (final s in actuels)
          if (s.id == souvenir.id) souvenir else s,
      ];
    });
  }

  /// Le seul endroit où un [SouvenirFeed] devient une [TablPublication] —
  /// ce qui varie d'un écran à l'autre arrive en paramètres.
  TablPublication construirePublication(
    SouvenirFeed souvenir, {
    required ContextePublication contexte,
    required VoidCallback onOuvrirLieu,
    VoidCallback? onOptions,
    SignalInstants? signal,
    VoidCallback? onOuvrirInstants,
    VoidCallback? onAjouterInstant,
  }) {
    return TablPublication(
      contexte: contexte,
      auteurPseudo: souvenir.auteurPseudo,
      auteurPhotoUrl: souvenir.auteurPhotoUrl,
      dateLisible: dateLisibleSouvenir(
        souvenir.dateVisite,
        jourConnu: souvenir.jourConnu,
      ),
      photoUrl: souvenir.photoUrl,
      autresPhotosUrls: souvenir.autresPhotosUrls,
      restaurantNom: souvenir.restaurantNom,
      ville: souvenir.ville,
      emojiEmotion: souvenir.emotion?.emoji,
      legende: legendeAffichee(souvenir.legende),
      impressions: souvenir.impressions,
      jaiReagi: souvenir.jaiReagi,
      libelleReactions: libelleReactionsSouvenir(souvenir),
      bullesReactions: bullesQuiOntAime(souvenir),
      enregistre: souvenir.estEnvie,
      audienceRestreinte: souvenir.audienceRestreinte,
      onReagir: () => basculerReaction(souvenir),
      onCommenter: () => ouvrirCommentaires(souvenir),
      onOuvrirLieu: onOuvrirLieu,
      onEnregistrer: () => basculerEnvie(souvenir),
      onOptions: onOptions,
      onTapAuteur: abonnementService == null || souvenir.estAMoi
          ? null
          : () => ouvrirProfil(souvenir),
      instantsTotal: signal?.total ?? 0,
      instantsNonVus: signal?.nonVus ?? 0,
      onOuvrirInstants: onOuvrirInstants,
      onAjouterInstant: onAjouterInstant,
    );
  }
}

/// Les têtes de ceux qui ont aimé [souvenir], à côté de « a aimé » —
/// sur une publication comme sur un moment agrandi.
List<BullePersonne> bullesQuiOntAime(SouvenirFeed souvenir) => [
  for (final p in visagesQuiOntAime(souvenir))
    BullePersonne(pseudo: p.pseudo, photoUrl: p.photoUrl),
];
