import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_accueil.dart';

/// Une étape statique du parcours de présentation.
class _DonneesEtape {
  const _DonneesEtape({
    required this.titre,
    required this.texte,
    required this.icone,
  });

  final String titre;
  final String texte;
  final IconData icone;
}

/// Les 5 étapes du parcours, dans l'ordre attendu (voir `data-model.md`).
const List<_DonneesEtape> _etapes = [
  _DonneesEtape(
    titre: 'Bienvenue',
    texte: 'Tabl, c\'est le carnet de tes sorties resto, entre amis.',
    icone: Icons.waving_hand_outlined,
  ),
  _DonneesEtape(
    titre: 'Profil',
    texte: 'Ton profil garde une trace de tes découvertes culinaires.',
    icone: Icons.person_outline_rounded,
  ),
  _DonneesEtape(
    titre: 'Feed',
    texte: 'Suis ce que tes amis mangent et où ils sortent.',
    icone: Icons.dynamic_feed_outlined,
  ),
  _DonneesEtape(
    titre: 'Réseau privé entre amis',
    texte: 'Tabl est privé par défaut : tu choisis qui voit ce que tu publies.',
    icone: Icons.lock_outline_rounded,
  ),
  _DonneesEtape(
    titre: 'Publication d\'un souvenir',
    texte: 'Immortalise une table, un plat, un moment partagé.',
    icone: Icons.photo_camera_outlined,
  ),
];

/// Écran de présentation affiché à la toute première ouverture de l'app.
///
/// Orchestre les 5 étapes de `widgets/etape_onboarding.dart` : progression
/// par swipe uniquement, jusqu'au bouton "Commencer" de la dernière étape,
/// qui amène à l'écran d'accueil et marque le parcours comme vu
/// (FR-006/FR-009).
class EcranOnboarding extends StatefulWidget {
  const EcranOnboarding({
    super.key,
    required this.authService,
    required this.abonnementService,
    required this.souvenirService,
    required this.etatOnboarding,
  });

  final AuthService authService;
  final AbonnementService abonnementService;
  final SouvenirService souvenirService;
  final EtatOnboarding etatOnboarding;

  @override
  State<EcranOnboarding> createState() => _EcranOnboardingState();
}

class _EcranOnboardingState extends State<EcranOnboarding> {
  final _controleur = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  Future<void> _terminerOnboarding() async {
    await widget.etatOnboarding.marquerOnboardingVu();
    if (!mounted) return;
    // `push`, pas `pushReplacement` : l'accueil garde l'onboarding en
    // dessous, pour que son bouton retour puisse y revenir. Le parcours
    // ne réapparaîtra pas pour autant au prochain lancement, puisque
    // `marquerOnboardingVu` est déjà passé (voir EcranDemarrage).
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranAccueil(
          authService: widget.authService,
          abonnementService: widget.abonnementService,
          souvenirService: widget.souvenirService,
        ),
      ),
    );
    // L'onboarding reste vivant sous l'accueil : sans ça, un retour
    // arrière rejoue la dernière étape vue plutôt que de repartir de
    // « Bienvenue ».
    if (!mounted) return;
    _controleur.jumpToPage(0);
    setState(() => _index = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controleur,
                itemCount: _etapes.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) {
                  final etape = _etapes[index];
                  final derniereEtape = index == _etapes.length - 1;
                  return EtapeOnboarding(
                    titre: etape.titre,
                    texte: etape.texte,
                    icone: etape.icone,
                    onPasser: derniereEtape ? _terminerOnboarding : null,
                    libellePasser: 'Commencer',
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: TablTokens.espaceL),
              child: TablIndicateurPage(total: _etapes.length, index: _index),
            ),
          ],
        ),
      ),
    );
  }
}
