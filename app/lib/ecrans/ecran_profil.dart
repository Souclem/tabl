import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_accueil.dart';
import 'ecran_cercle.dart';
import 'ecran_tables.dart';

/// Onglet Profil : identité de l'utilisateur, accès au cercle et
/// déconnexion.
///
/// Volontairement minimal pour l'instant — stats, souvenirs et historique
/// viendront une fois les données réelles disponibles (voir maquette
/// Claude Design pour la version complète visée).
class EcranProfil extends StatefulWidget {
  const EcranProfil({
    super.key,
    required this.authService,
    required this.abonnementService,
    required this.souvenirService,
    required this.utilisateur,
    this.tableService,
  });

  final AuthService authService;
  final AbonnementService abonnementService;
  final SouvenirService souvenirService;
  final Utilisateur utilisateur;

  /// `null` par défaut : construit à la demande (au tap de "Vos
  /// Tables") à partir de `TablBackend.client`, même principe que
  /// `EcranPrincipal.carteService` — ne jamais toucher `TablBackend`
  /// avant que ce soit nécessaire.
  final TableService? tableService;

  @override
  State<EcranProfil> createState() => _EcranProfilState();
}

class _EcranProfilState extends State<EcranProfil> {
  bool _enCours = false;

  // Recalculé seulement à la création de l'état et au retour de l'écran
  // Cercle (voir _allerVersCercle) — jamais à chaque reconstruction, sans
  // quoi un changement d'onglet dans l'IndexedStack parent ou toute autre
  // reconstruction sans rapport relancerait la requête et ferait
  // clignoter le badge à 0 le temps qu'elle reparte.
  late Future<int> _nombreDemandes =
      widget.abonnementService.nombreDemandesEnAttente();

  Future<void> _allerVersCercle() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EcranCercle(abonnementService: widget.abonnementService),
      ),
    );
    if (!mounted) return;
    setState(() {
      _nombreDemandes = widget.abonnementService.nombreDemandesEnAttente();
    });
  }

  void _allerVersTables() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranTables(
          tableService: widget.tableService ?? TableServiceSupabase(TablBackend.client),
          abonnementService: widget.abonnementService,
        ),
      ),
    );
  }

  Future<void> _seDeconnecter() async {
    setState(() => _enCours = true);
    try {
      await widget.authService.deconnexion();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        EcranAccueil.route(
          widget.authService,
          widget.abonnementService,
          widget.souvenirService,
        ),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
      setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(TablTokens.espaceL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: TablTokens.espaceXl),
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: TablTokens.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        widget.utilisateur.pseudo.isNotEmpty
                            ? widget.utilisateur.pseudo[0].toUpperCase()
                            : '?',
                        style: TablTokens.grandTitre,
                      ),
                    ),
                  ),
                  const SizedBox(height: TablTokens.espaceM),
                  Text(
                    widget.utilisateur.pseudo,
                    textAlign: TextAlign.center,
                    style: TablTokens.titre,
                  ),
                  const SizedBox(height: TablTokens.espaceXs),
                  Text(
                    widget.utilisateur.email,
                    textAlign: TextAlign.center,
                    style: TablTokens.corps.copyWith(
                      color: TablTokens.texteDoux,
                    ),
                  ),
                  const SizedBox(height: TablTokens.espaceXxl),
                  TablBouton(
                    libelle: 'Se déconnecter',
                    enCours: _enCours,
                    onPresse: _seDeconnecter,
                  ),
                ],
              ),
            ),
            Positioned(
              top: TablTokens.espaceS,
              right: TablTokens.espaceM,
              child: Row(
                children: [
                  _BoutonIcone(
                    icone: Icons.table_restaurant_outlined,
                    libelle: 'Vos Tables',
                    onPresse: _allerVersTables,
                  ),
                  const SizedBox(width: TablTokens.espaceS),
                  _BoutonCercle(
                    nombreDemandes: _nombreDemandes,
                    onPresse: _allerVersCercle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icône ronde simple, même habillage que [_BoutonCercle] mais sans
/// badge — pour "Vos Tables".
class _BoutonIcone extends StatelessWidget {
  const _BoutonIcone({
    required this.icone,
    required this.libelle,
    required this.onPresse,
  });

  final IconData icone;
  final String libelle;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TablTokens.surface,
      shape: const CircleBorder(side: BorderSide(color: TablTokens.bordure)),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: onPresse,
        icon: Icon(icone, size: 20),
        color: TablTokens.primaire,
        splashRadius: 22,
        tooltip: libelle,
      ),
    );
  }
}

/// Icône vers l'écran Cercle, avec un badge si des demandes de suivi
/// sont en attente.
class _BoutonCercle extends StatelessWidget {
  const _BoutonCercle({required this.nombreDemandes, required this.onPresse});

  final Future<int> nombreDemandes;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: nombreDemandes,
      builder: (context, snapshot) {
        final nombre = snapshot.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: TablTokens.surface,
              shape: const CircleBorder(
                side: BorderSide(color: TablTokens.bordure),
              ),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                onPressed: onPresse,
                icon: const Icon(Icons.people_outline_rounded, size: 20),
                color: TablTokens.primaire,
                splashRadius: 22,
              ),
            ),
            if (nombre > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  height: 17,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: TablTokens.primaire,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$nombre',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: TablTokens.texteSurPrimaire,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
