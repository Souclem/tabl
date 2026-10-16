import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'actions_publications.dart';

/// Une publication ouverte en entier, exactement comme dans le Feed
/// (même composant, mêmes actions) — depuis la page d'un restaurant, où
/// elle n'apparaît qu'en version compacte.
class EcranPublication extends StatefulWidget {
  const EcranPublication({
    super.key,
    required this.souvenir,
    required this.souvenirService,
  });

  final SouvenirFeed souvenir;
  final SouvenirService souvenirService;

  @override
  State<EcranPublication> createState() => _EcranPublicationState();
}

class _EcranPublicationState extends State<EcranPublication>
    with ActionsPublications<EcranPublication> {
  @override
  SouvenirService get souvenirService => widget.souvenirService;

  @override
  void initState() {
    super.initState();
    souvenirs = [widget.souvenir];
  }

  /// Rien à recharger ici : la page du restaurant se met à jour au
  /// retour.
  @override
  void recharger() {}

  @override
  Widget build(BuildContext context) {
    final souvenir = souvenirs!.single;
    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: TablTokens.espaceXl),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TablTokens.espaceM,
                TablTokens.espaceS,
                TablTokens.espaceM,
                TablTokens.espaceM,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TablBoutonRetour(
                  onPresse: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            construirePublication(
              souvenir,
              contexte: ContextePublication.feed,
              // On vient de la page de ce restaurant : y revenir.
              onOuvrirLieu: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
