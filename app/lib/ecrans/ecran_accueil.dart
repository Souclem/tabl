import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import '../navigation/connexion_oauth.dart';
import '../navigation/transitions.dart';
import 'ecran_choix_pseudo.dart';
import 'ecran_connexion.dart';
import 'ecran_inscription.dart';
import 'ecran_principal.dart';

/// Écran d'accueil affiché à l'issue de la présentation : le point d'entrée
/// unique vers la création de compte (Apple, Google ou e-mail) ou vers la
/// connexion, pour qui a déjà un compte.
class EcranAccueil extends StatefulWidget {
  const EcranAccueil({
    super.key,
    required this.authService,
    required this.abonnementService,
    required this.souvenirService,
  });

  final AuthService authService;
  final AbonnementService abonnementService;
  final SouvenirService souvenirService;

  /// Route standard vers l'accueil. Centralisé ici pour que tous les
  /// écrans qui y reviennent (voir [revenirVersAccueilOuSecours]) créent
  /// la même route, avec le même wiring.
  static Route<void> route(
    AuthService authService,
    AbonnementService abonnementService,
    SouvenirService souvenirService,
  ) {
    return MaterialPageRoute<void>(
      builder: (_) => EcranAccueil(
        authService: authService,
        abonnementService: abonnementService,
        souvenirService: souvenirService,
      ),
    );
  }

  @override
  State<EcranAccueil> createState() => _EcranAccueilState();
}

/// Bouton retour défensif standard des écrans atteints depuis l'accueil :
/// dépile s'il y a quelque chose en dessous (l'accueil, normalement),
/// sinon y retourne en le recréant (voir [revenirOuSecours]).
void revenirVersAccueilOuSecours(
  BuildContext context,
  AuthService authService,
  AbonnementService abonnementService,
  SouvenirService souvenirService,
) {
  revenirOuSecours(
    context,
    () => Navigator.of(context).pushReplacement(
      EcranAccueil.route(authService, abonnementService, souvenirService),
    ),
  );
}

class _EcranAccueilState extends State<EcranAccueil>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entree = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  bool _enCours = false;

  @override
  void dispose() {
    _entree.dispose();
    super.dispose();
  }

  Future<void> _connexionApple() =>
      _connexionOAuth(widget.authService.connexionApple);

  Future<void> _connexionGoogle() =>
      _connexionOAuth(widget.authService.connexionGoogle);

  Future<void> _connexionOAuth(
    Future<ResultatConnexionOAuth?> Function() connexion,
  ) async {
    setState(() => _enCours = true);
    final resultat = await tenterConnexionOAuth(context, connexion);
    if (mounted) setState(() => _enCours = false);
    if (!mounted || resultat == null) return;

    switch (resultat) {
      case ConnexionOAuthReussie(:final utilisateur):
        Navigator.of(context).pushReplacement(
          EcranPrincipal.route(
            authService: widget.authService,
            abonnementService: widget.abonnementService,
            souvenirService: widget.souvenirService,
            utilisateur: utilisateur,
          ),
        );
      case ProfilAConfigurer(:final id, :final email):
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => EcranChoixPseudo(
              authService: widget.authService,
              abonnementService: widget.abonnementService,
              souvenirService: widget.souvenirService,
              id: id,
              email: email,
            ),
          ),
        );
    }
  }

  void _allerVersInscription() {
    Navigator.of(context).push(
      ouvrirFormulaire(
        EcranInscription(
          authService: widget.authService,
          abonnementService: widget.abonnementService,
          souvenirService: widget.souvenirService,
        ),
      ),
    );
  }

  void _allerVersConnexion() {
    Navigator.of(context).push(
      ouvrirFormulaire(
        EcranConnexion(
          authService: widget.authService,
          abonnementService: widget.abonnementService,
          souvenirService: widget.souvenirService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Scaffold(
      body: TablFondHeros(
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TablTokens.espaceL,
                ),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    TablEntreeEchelonnee(
                      controleur: _entree,
                      debut: 0,
                      fin: 0.55,
                      depart: const Offset(0, -0.15),
                      child: Column(
                        children: [
                          TablLogo(grand: true),
                          SizedBox(height: TablTokens.espaceM),
                          SizedBox(width: 40, child: Divider(color: c.bordure)),
                        ],
                      ),
                    ),
                    const SizedBox(height: TablTokens.espaceL),
                    TablEntreeEchelonnee(
                      controleur: _entree,
                      debut: 0.15,
                      fin: 0.7,
                      depart: const Offset(0, 0.15),
                      child: Text.rich(
                        TextSpan(
                          style: c.corps.copyWith(fontSize: 19, height: 1.4),
                          children: [
                            TextSpan(
                              text: 'Partagez les bonnes adresses avec ',
                            ),
                            TextSpan(
                              text: 'les personnes qui comptent vraiment.',
                              style: TextStyle(color: c.primaire),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Spacer(flex: 4),
                    TablEntreeEchelonnee(
                      controleur: _entree,
                      debut: 0.35,
                      fin: 0.9,
                      depart: const Offset(0, 0.2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TablBoutonsAuthTierce(
                            pilule: true,
                            styleApple: TablBoutonSocialStyle.clair,
                            styleGoogle: TablBoutonSocialStyle.sombre,
                            avecApple: connexionAppleProposee,
                            onPresseApple: _enCours ? null : _connexionApple,
                            onPresseGoogle: _enCours ? null : _connexionGoogle,
                          ),
                          const SizedBox(height: TablTokens.espaceM),
                          TablBoutonSocial(
                            libelle: 'Créer un compte avec un e-mail',
                            icone: Icons.mail_outline_rounded,
                            style: TablBoutonSocialStyle.contourAccent,
                            pilule: true,
                            onPresse: _enCours ? null : _allerVersInscription,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: TablTokens.espaceXl),
                    TablEntreeEchelonnee(
                      controleur: _entree,
                      debut: 0.55,
                      fin: 1,
                      child: Column(
                        children: [
                          const TablSeparateurTexte(
                            texte: 'DÉJÀ MEMBRE ?',
                            espacementLettres: 1.2,
                          ),
                          const SizedBox(height: TablTokens.espaceM),
                          TablBoutonTexte(
                            libelle: 'Se connecter  →',
                            onPresse: _allerVersConnexion,
                          ),
                          const SizedBox(height: TablTokens.espaceL),
                          Text(
                            "En continuant, vous acceptez nos Conditions "
                            "d'utilisation et notre Politique de confidentialité.",
                            textAlign: TextAlign.center,
                            style: c.legende,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: TablTokens.espaceM),
                  ],
                ),
              ),
              // Rien à faire du bouton retour si l'accueil est déjà la
              // racine de la navigation : un fallback vide laisserait une
              // flèche visible mais durablement inerte, un faux espoir de
              // sortie. On ne l'affiche que s'il y a réellement quelque
              // chose en dessous.
              if (Navigator.of(context).canPop())
                Positioned(
                  top: TablTokens.espaceS,
                  left: TablTokens.espaceM,
                  child: TablBoutonRetour(
                    onPresse: () => Navigator.of(context).pop(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
