import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_explorer.dart';
import 'ecran_feed.dart';
import 'ecran_profil.dart';
import 'ecran_publier.dart';

/// Coquille de l'app une fois connecté : barre de navigation en bas
/// (Feed, Explorer, publier, Wishlist, Profil). Wishlist attend encore
/// son écran.
class EcranPrincipal extends StatefulWidget {
  const EcranPrincipal({
    super.key,
    required this.authService,
    required this.abonnementService,
    required this.souvenirService,
    required this.utilisateur,
    this.carteService,
    this.raccourcisVillesService,
    this.entitlementService,
    this.tableService,
    this.instantService,
  });

  final AuthService authService;
  final AbonnementService abonnementService;
  final SouvenirService souvenirService;
  final Utilisateur utilisateur;

  /// `null` par défaut : construits ici même à partir de
  /// `TablBackend.client`, pour ne pas obliger tous les écrans qui
  /// amènent à `EcranPrincipal` (connexion, inscription, choix du
  /// pseudo, attente de confirmation, accueil...) à connaître ces
  /// services alors qu'ils ne les utilisent jamais eux-mêmes. Les tests
  /// injectent des faux via ces mêmes paramètres.
  final CarteService? carteService;
  final RaccourcisVillesService? raccourcisVillesService;
  final EntitlementService? entitlementService;
  final TableService? tableService;
  final InstantService? instantService;

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

  // L'onglet Explorer n'est construit qu'une fois réellement ouvert :
  // IndexedStack construit sinon tous ses enfants dès le premier
  // affichage de l'écran, ce qui déclencherait un appel réseau (et,
  // sans backend explicitement injecté, un accès à `TablBackend.client`
  // avant que Supabase ne soit forcément initialisé) même pour un
  // utilisateur qui ne visite jamais cet onglet.
  bool _explorerConstruit = false;

  late final CarteService _carteService =
      widget.carteService ?? CarteServiceSupabase(TablBackend.client);
  late final RaccourcisVillesService _raccourcisVillesService =
      widget.raccourcisVillesService ?? RaccourcisVillesServicePreferences();
  late final EntitlementService _entitlementService =
      widget.entitlementService ?? const EntitlementServiceGratuit();
  late final TableService _tableService =
      widget.tableService ?? TableServiceSupabase(TablBackend.client);

  void _selectionnerOnglet(TablOnglet onglet) {
    setState(() {
      _onglet = onglet;
      if (onglet == TablOnglet.explorer) _explorerConstruit = true;
    });
  }

  void _publier() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranPublier(
          souvenirService: widget.souvenirService,
          abonnementService: widget.abonnementService,
          tableService: _tableService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablTokens.fond,
      // La barre flotte au-dessus du contenu (Stack), plutôt que
      // `bottomNavigationBar` qui la coincerait pleine largeur contre le
      // bord — voir la note de classe de TablBarreNavigation.
      body: Stack(
        children: [
          IndexedStack(
            index: _onglet.index,
            children: [
              EcranFeed(
                souvenirService: widget.souvenirService,
                abonnementService: widget.abonnementService,
                instantService: widget.instantService,
              ),
              _explorerConstruit
                  ? EcranExplorer(
                      carteService: _carteService,
                      abonnementService: widget.abonnementService,
                      raccourcisVillesService: _raccourcisVillesService,
                      entitlementService: _entitlementService,
                    )
                  : const _EcranOngletAVenir(titre: 'Explorer'),
              const _EcranOngletAVenir(titre: 'Wishlist'),
              EcranProfil(
                authService: widget.authService,
                abonnementService: widget.abonnementService,
                souvenirService: widget.souvenirService,
                utilisateur: widget.utilisateur,
                // `widget.tableService` (nullable) et non `_tableService` :
                // EcranProfil est construit eagerly (pas de lazy comme
                // Explorer) — `_tableService` y accéderait dès le premier
                // build et construirait `TableServiceSupabase` avant que
                // Supabase soit forcément initialisé. EcranProfil a déjà
                // son propre fallback paresseux (au tap de "Vos Tables").
                tableService: widget.tableService,
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TablBarreNavigation(
              ongletActif: _onglet,
              onSelection: _selectionnerOnglet,
              onPublier: _publier,
            ),
          ),
        ],
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
