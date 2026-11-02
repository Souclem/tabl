import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Ce que partagent le Feed et l'écran Abonnés autour des suggestions
/// d'amis : les charger, suivre (ou y renoncer), en écarter, ouvrir un
/// profil. Chaque geste se voit tout de suite sur la vignette.
mixin GestionSuggestions<T extends StatefulWidget> on State<T> {
  AbonnementService get abonnementService;

  /// Ouvre le profil d'une personne suggérée ; l'écran s'occupe de ce
  /// qui se recharge au retour.
  Future<void> ouvrirProfilSuggere(String profilId, String pseudo);

  /// Je viens de suivre quelqu'un (ou d'y renoncer) depuis une
  /// suggestion : où j'en suis maintenant avec lui.
  void apresSuiviSuggere(StatutAbonnement statut) {}

  /// `null` tant qu'elles ne sont pas chargées.
  List<SuggestionAmi>? suggestions;

  final Set<String> _suggestionsEnCours = {};

  Future<void> chargerSuggestions() async {
    try {
      final liste = await abonnementService.suggestions();
      if (!mounted) return;
      setState(() => suggestions = liste);
    } catch (e) {
      // Un plus, pas l'essentiel : sans elles, rien ne manque à l'écran.
      debugPrint('Suggestions: chargement : $e');
      if (mounted) setState(() => suggestions = const []);
    }
  }

  /// « Suivre » ou « Suivre en retour » ; une fois suivie, toucher
  /// « Abonné » ou « Demande envoyée » revient en arrière, comme dans
  /// les listes d'abonnés.
  Future<void> _basculerSuivi(SuggestionAmi s) async {
    setState(() => _suggestionsEnCours.add(s.id));
    try {
      final StatutAbonnement statut;
      if (s.profil.statut == StatutAbonnement.aucun) {
        statut = await abonnementService.suivre(s.id);
      } else {
        await abonnementService.arreterDeSuivre(s.id);
        statut = StatutAbonnement.aucun;
      }
      if (!mounted) return;
      actualiserSuggestion(s.id, statut);
      apresSuiviSuggere(statut);
    } catch (e) {
      debugPrint('Suggestions: suivi : $e');
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => _suggestionsEnCours.remove(s.id));
    }
  }

  /// Où j'en suis avec [profilId], suivi ailleurs sur l'écran : sa
  /// vignette, s'il en a une, le montre aussi.
  void actualiserSuggestion(String profilId, StatutAbonnement statut) {
    final liste = suggestions;
    if (liste == null || !liste.any((x) => x.id == profilId)) return;
    setState(() {
      suggestions = [
        for (final x in liste)
          x.id == profilId ? x.copierAvec(statut: statut) : x,
      ];
    });
  }

  Future<void> _ecarter(SuggestionAmi s) async {
    final avant = suggestions;
    if (avant == null) return;
    setState(
      () => suggestions = [
        for (final x in avant)
          if (x.id != s.id) x,
      ],
    );
    try {
      await abonnementService.ecarterSuggestion(s.id);
    } catch (e) {
      debugPrint('Suggestions: écarter : $e');
      if (!mounted) return;
      setState(() => suggestions = avant);
      afficherMessage(context, messageErreurGenerique);
    }
  }

  /// La carte, prête à afficher ; `null` s'il n'y a personne à proposer.
  Widget? get carteSuggestions {
    final liste = suggestions;
    if (liste == null || liste.isEmpty) return null;
    return TablCarteSuggestions(
      suggestions: [
        for (final s in liste)
          SuggestionAffichee(
            pseudo: s.profil.pseudo,
            photoUrl: s.profil.photoUrl,
            raison: raisonSuggestion(s),
            libelleBouton: libelleSuivreSuggestion(s),
            boutonPlein: s.profil.statut == StatutAbonnement.aucun,
            onBouton: _suggestionsEnCours.contains(s.id)
                ? null
                : () => _basculerSuivi(s),
            onEcarter: () => _ecarter(s),
            onOuvrir: () => ouvrirProfilSuggere(s.id, s.profil.pseudo),
          ),
      ],
    );
  }
}
