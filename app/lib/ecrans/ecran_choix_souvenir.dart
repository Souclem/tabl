import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_ajouter_souvenir.dart';

/// « Comment retrouver vos souvenirs ? » : en ajouter un seul à la main,
/// ou plusieurs d'un coup depuis ses photos. Se ferme sur `true` dès
/// qu'un souvenir a été ajouté.
class EcranChoixSouvenir extends StatelessWidget {
  const EcranChoixSouvenir({
    super.key,
    required this.souvenirService,
    required this.abonnementService,
    this.tableService,
    this.rechercheLieuService,
    this.positionService,
  });

  final SouvenirService souvenirService;
  final AbonnementService abonnementService;
  final TableService? tableService;
  final RechercheLieuService? rechercheLieuService;
  final PositionService? positionService;

  Future<void> _ajouterUnSouvenir(BuildContext context) async {
    final ajoute = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EcranAjouterSouvenir(
          souvenirService: souvenirService,
          abonnementService: abonnementService,
          tableService: tableService,
          rechercheLieuService: rechercheLieuService,
          positionService: positionService,
        ),
      ),
    );
    if (ajoute == true && context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TablTokens.espaceL,
            TablTokens.espaceS,
            TablTokens.espaceL,
            TablTokens.espaceL,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TablBoutonRetour(
                  onPresse: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(height: TablTokens.espaceL),
              Text(
                'Comment retrouver vos souvenirs ?',
                style: TablTokens.grandTitre,
              ),
              const SizedBox(height: TablTokens.espaceS),
              Text(
                'Vos repas passés se rangent à leur date sur votre profil, '
                'jamais dans le Feed.',
                style: TablTokens.legende,
              ),
              const SizedBox(height: TablTokens.espaceXl),
              const TablMethodeSouvenir(
                icone: Icons.auto_awesome_outlined,
                titre: 'Ajouter plusieurs de manière intelligente',
                texte:
                    'Depuis vos photos : Tabl retrouve le lieu et le moment, '
                    'vous confirmez.',
                mention: 'Bientôt',
              ),
              const SizedBox(height: TablTokens.espaceM),
              TablMethodeSouvenir(
                icone: Icons.edit_outlined,
                titre: 'Ajouter un souvenir',
                texte: 'Un repas, avec ou sans photo.',
                onPresse: () => _ajouterUnSouvenir(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
