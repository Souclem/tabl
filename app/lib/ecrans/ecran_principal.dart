import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_carte.dart';
import 'ecran_feed.dart';
import 'ecran_profil.dart';
import 'ecran_publier.dart';
import 'ecran_tables.dart';

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
    this.tableService,
    this.instantService,
    this.notificationService,
    this.avisService,
    this.rechercheLieuService,
    this.positionService,
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
  final TableService? tableService;
  final InstantService? instantService;
  final NotificationService? notificationService;
  final AvisService? avisService;
  final RechercheLieuService? rechercheLieuService;
  final PositionService? positionService;

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

  /// La barre se tasse pendant qu'on descend dans une liste, et reprend
  /// sa taille dès qu'on s'arrête un instant.
  bool _barreCompacte = false;
  Timer? _reprise;
  double _derniereHauteur = 0;

  bool _defilement(ScrollUpdateNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final y = notification.metrics.pixels;
    final descend = y > _derniereHauteur + 2;
    _derniereHauteur = y;
    final compacte = descend && y > 80;
    if (compacte != _barreCompacte) setState(() => _barreCompacte = compacte);
    _reprise?.cancel();
    _reprise = Timer(const Duration(milliseconds: 700), () {
      if (mounted && _barreCompacte) setState(() => _barreCompacte = false);
    });
    return false;
  }

  @override
  void dispose() {
    _reprise?.cancel();
    super.dispose();
  }

  // Les onglets Tables et Carte ne sont construits qu'une fois réellement
  // ouverts : IndexedStack construit sinon tous ses enfants dès le
  // premier affichage, ce qui déclencherait des appels réseau (et, sans
  // backend injecté, un accès à `TablBackend.client` avant que Supabase
  // ne soit forcément initialisé) même pour qui ne les visite jamais —
  // et la carte Mapbox est lourde à démarrer.
  final Set<TablOnglet> _ongletsConstruits = {
    TablOnglet.feed,
    TablOnglet.profil,
  };

  // Le Feed en a besoin dès son premier build. Venu de `main`, ils sont
  // passés ; après une connexion ([route]), on les construit ici — si
  // Supabase est démarré, donc jamais dans les tests sans backend.
  late final InstantService? _instantService =
      widget.instantService ??
      (TablBackend.estDemarre
          ? InstantServiceSupabase(TablBackend.client)
          : null);
  late final NotificationService? _notificationService =
      widget.notificationService ??
      (TablBackend.estDemarre
          ? NotificationServiceSupabase(TablBackend.client)
          : null);

  late final CarteService _carteService =
      widget.carteService ?? CarteServiceSupabase(TablBackend.client);
  // Paresseux comme les autres : seulement à l'ouverture d'Explorer.
  late final AvisService _avisService =
      widget.avisService ?? AvisServiceSupabase(TablBackend.client);
  late final TableService _tableService =
      widget.tableService ?? TableServiceSupabase(TablBackend.client);
  late final RechercheLieuService _rechercheLieuService =
      widget.rechercheLieuService ??
      RechercheLieuServiceSupabase(TablBackend.client);
  late final PositionService _positionService =
      widget.positionService ?? PositionServiceGeolocator();

  void _selectionnerOnglet(TablOnglet onglet) {
    setState(() {
      _onglet = onglet;
      _ongletsConstruits.add(onglet);
    });
  }

  void _publier() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranPublier(
          souvenirService: widget.souvenirService,
          abonnementService: widget.abonnementService,
          tableService: _tableService,
          rechercheLieuService: _rechercheLieuService,
          positionService: _positionService,
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
          NotificationListener<ScrollUpdateNotification>(
            onNotification: _defilement,
            child: IndexedStack(
              index: _onglet.index,
              children: [
                EcranFeed(
                  souvenirService: widget.souvenirService,
                  abonnementService: widget.abonnementService,
                  instantService: _instantService,
                  notificationService: _notificationService,
                ),
                _ongletsConstruits.contains(TablOnglet.tables)
                    ? EcranTables(
                        tableService: _tableService,
                        abonnementService: widget.abonnementService,
                        souvenirService: widget.souvenirService,
                        estOnglet: true,
                      )
                    : const SizedBox.shrink(),
                _ongletsConstruits.contains(TablOnglet.carte)
                    ? EcranCarte(
                        carteService: _carteService,
                        positionService: _positionService,
                        tableService: _tableService,
                        abonnementService: widget.abonnementService,
                        souvenirService: widget.souvenirService,
                        avisService: _avisService,
                      )
                    : const SizedBox.shrink(),
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
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TablBarreNavigation(
              ongletActif: _onglet,
              onSelection: _selectionnerOnglet,
              onPublier: _publier,
              compacte: _barreCompacte,
            ),
          ),
        ],
      ),
    );
  }
}
