import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_commentaires.dart';

/// Ce que partagent tous les écrans qui affichent une liste de
/// publications (Feed, profils) : la liste chargée, la réaction
/// optimiste, l'ouverture des commentaires, et la traduction d'un
/// [SouvenirFeed] en [TablPublication] prête à afficher.
mixin ActionsPublications<T extends StatefulWidget> on State<T> {
  SouvenirService get souvenirService;

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

  void remplacer(SouvenirFeed souvenir) {
    final actuels = souvenirs;
    if (actuels == null) return;
    setState(() {
      souvenirs = [
        for (final s in actuels) if (s.id == souvenir.id) souvenir else s,
      ];
    });
  }

  /// Le seul endroit où un [SouvenirFeed] devient une [TablPublication] —
  /// ce qui varie d'un écran à l'autre arrive en paramètres.
  TablPublication construirePublication(
    SouvenirFeed souvenir, {
    required ContextePublication contexte,
    required VoidCallback onOuvrirLieu,
    bool enregistre = false,
    VoidCallback? onEnregistrer,
    VoidCallback? onOptions,
    SignalInstants? signal,
    VoidCallback? onOuvrirInstants,
    VoidCallback? onAjouterInstant,
  }) {
    return TablPublication(
      contexte: contexte,
      auteurPseudo: souvenir.auteurPseudo,
      dateLisible: dateLisibleSouvenir(souvenir.dateVisite),
      photoUrl: souvenir.photoUrl,
      restaurantNom: souvenir.restaurantNom,
      ville: souvenir.ville,
      emojiEmotion: souvenir.emotion?.emoji,
      legende: souvenir.legende,
      impressions: souvenir.impressions,
      jaiReagi: souvenir.jaiReagi,
      libelleReactions: libelleReactionsSouvenir(souvenir),
      enregistre: enregistre,
      audienceRestreinte: souvenir.audienceRestreinte,
      onReagir: () => basculerReaction(souvenir),
      onCommenter: () => ouvrirCommentaires(souvenir),
      onOuvrirLieu: onOuvrirLieu,
      onEnregistrer: onEnregistrer,
      onOptions: onOptions,
      instantsTotal: signal?.total ?? 0,
      instantsNonVus: signal?.nonVus ?? 0,
      onOuvrirInstants: onOuvrirInstants,
      onAjouterInstant: onAjouterInstant,
    );
  }
}
