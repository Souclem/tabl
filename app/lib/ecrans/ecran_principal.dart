import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_feed.dart';
import 'ecran_profil.dart';
import 'ecran_publier.dart';

/// Coquille de l'app une fois connecté : barre de navigation en bas
/// (Feed, Explorer, publier, Wishlist, Profil). Seuls Feed, Profil et la
/// publication sont implémentés pour l'instant — Explorer et Wishlist
/// attendent leurs écrans.
class EcranPrincipal extends StatefulWidget {
  const EcranPrincipal({
    super.key,
    required this.authService,
    required this.abonnementService,
    required this.souvenirService,
    required this.utilisateur,
  });

  final AuthService authService;
  final AbonnementService abonnementService;
  final SouvenirService souvenirService;
  final Utilisateur utilisateur;

  /// Route standard vers l'écran principal, une fois connecté. Centralisé
  /// ici (même principe que `EcranAccueil.route`) pour que tous les
  /// écrans qui y amènent (connexion, inscription, choix du pseudo,
  /// attente de confirmation...) construisent le même wiring, sans
  /// répéter les trois services à chaque appel.
  static Route<void> route({
    required AuthService authService,
    required AbonnementService abonnementService,
    required SouvenirService souvenirService,
    required Utilisateur utilisateur,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => EcranPrincipal(
        authService: authService,
        abonnementService: abonnementService,
        souvenirService: souvenirService,
        utilisateur: utilisateur,
      ),
    );
  }

  @override
  State<EcranPrincipal> createState() => _EcranPrincipalState();
}

class _EcranPrincipalState extends State<EcranPrincipal> {
  TablOnglet _onglet = TablOnglet.feed;

  void _publier() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EcranPublier(souvenirService: widget.souvenirService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: IndexedStack(
        index: _onglet.index,
        children: [
          EcranFeed(
            souvenirService: widget.souvenirService,
            abonnementService: widget.abonnementService,
          ),
          const _EcranOngletAVenir(titre: 'Explorer'),
          const _EcranOngletAVenir(titre: 'Wishlist'),
          EcranProfil(
            authService: widget.authService,
            abonnementService: widget.abonnementService,
            souvenirService: widget.souvenirService,
            utilisateur: widget.utilisateur,
          ),
        ],
      ),
      bottomNavigationBar: TablBarreNavigation(
        ongletActif: _onglet,
        onSelection: (onglet) => setState(() => _onglet = onglet),
        onPublier: _publier,
      ),
    );
  }
}

/// Contenu d'un onglet pas encore implémenté.
class _EcranOngletAVenir extends StatelessWidget {
  const _EcranOngletAVenir({required this.titre});

  final String titre;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$titre — bientôt disponible.',
        style: TablTokens.corps.copyWith(color: TablTokens.texteDoux),
      ),
    );
  }
}
