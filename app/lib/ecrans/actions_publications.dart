import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_commentaires.dart';
import 'ecran_profil_autre.dart';
import 'feuille_restaurant.dart';

/// Ce que partagent tous les écrans qui affichent une liste de
/// publications (Feed, profils) : la liste chargée, la réaction
/// optimiste, l'ouverture des commentaires, et la traduction d'un
/// [SouvenirFeed] en [TablPublication] prête à afficher.
mixin ActionsPublications<T extends StatefulWidget> on State<T> {
  SouvenirService get souvenirService;

  /// Pour ouvrir le profil d'un auteur ; `null` (par défaut) : les
  /// auteurs ne sont pas touchables.
  AbonnementService? get abonnementService => null;

  /// La publication dépliée sur place (une seule à la fois), voir
  /// [publicationDepliable].
  String? publicationOuverte;

  /// `null` tant que le premier chargement n'est pas terminé. Mutable :
  /// une réaction met à jour la liste en place, sans tout recharger.
  List<SouvenirFeed>? souvenirs;

  /// Relance le chargement complet de la liste — appelé au retour des
  /// commentaires, dont le nombre a pu changer.
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

  Future<void> ouvrirCommentaires(SouvenirFeed souvenir) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranCommentaires(
          souvenirService: souvenirService,
          souvenirId: souvenir.id,
        ),
      ),
    );
    // Le nombre de commentaires a pu changer pendant la visite : on
    // recharge tout au retour plutôt que de suivre les ajouts un par un
    // — plus simple, et cet écran n'est pas quitté souvent.
    if (!mounted) return;
    recharger();
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
      restaurantNom: souvenir.restaurantNom,
      ville: souvenir.ville,
      emojiEmotion: souvenir.emotion?.emoji,
      legende: legendeAffichee(souvenir.legende),
      impressions: souvenir.impressions,
      jaiReagi: souvenir.jaiReagi,
      libelleReactions: libelleReactionsSouvenir(souvenir),
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
