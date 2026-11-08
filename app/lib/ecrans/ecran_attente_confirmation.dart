import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_accueil.dart';
import 'ecran_principal.dart';

/// Affiché juste après l'inscription quand la confirmation par e-mail est
/// requise. Vérifie si le compte est devenu utilisable (l'utilisateur a
/// cliqué le lien de confirmation) au retour dans l'app — on revient de
/// sa boîte mail — et de temps en temps, puis enchaîne automatiquement
/// sur [EcranPrincipal] — pas besoin que l'utilisateur revienne
/// manuellement se connecter.
class EcranAttenteConfirmation extends StatefulWidget {
  const EcranAttenteConfirmation({
    super.key,
    required this.authService,
    required this.abonnementService,
    required this.souvenirService,
    required this.email,
    required this.motDePasse,
  });

  final AuthService authService;
  final AbonnementService abonnementService;
  final SouvenirService souvenirService;
  final String email;
  final String motDePasse;

  @override
  State<EcranAttenteConfirmation> createState() =>
      _EcranAttenteConfirmationState();
}

class _EcranAttenteConfirmationState extends State<EcranAttenteConfirmation>
    with WidgetsBindingObserver {
  /// Chaque vérification est une tentative de connexion, et Supabase en
  /// accepte une trentaine par 5 minutes : plus souvent, la connexion
  /// serait refusée encore un moment après la confirmation.
  static const _intervalle = Duration(seconds: 15);

  Timer? _minuteur;
  bool _verificationEnCours = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _minuteur = Timer.periodic(_intervalle, (_) => _verifier());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _minuteur?.cancel();
    super.dispose();
  }

  /// De retour de la boîte mail : le lien vient sans doute d'être
  /// touché.
  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    if (etat == AppLifecycleState.resumed) _verifier();
  }

  Future<void> _verifier() async {
    if (_verificationEnCours) return;
    _verificationEnCours = true;
    try {
      // Tant que l'e-mail n'est pas confirmé, Supabase refuse la
      // connexion : c'est justement ce refus qui sert de sonde. Le jour
      // où elle réussit, l'e-mail vient d'être confirmé.
      final utilisateur = await widget.authService.connexion(
        email: widget.email,
        motDePasse: widget.motDePasse,
      );
      if (!mounted) return;
      _minuteur?.cancel();
      Navigator.of(context).pushReplacement(
        EcranPrincipal.route(
          authService: widget.authService,
          abonnementService: widget.abonnementService,
          souvenirService: widget.souvenirService,
          utilisateur: utilisateur,
        ),
      );
    } on ErreurAuth {
      // Pas encore confirmé (ou autre souci passager) : on retentera au
      // prochain tic du minuteur.
    } finally {
      _verificationEnCours = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(TablTokens.espaceL),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: TablTokens.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mail_outline_rounded,
                        size: 44,
                        color: TablTokens.primaire,
                      ),
                    ),
                    const SizedBox(height: TablTokens.espaceXl),
                    Text(
                      'Vérifie ta boîte mail',
                      textAlign: TextAlign.center,
                      style: TablTokens.grandTitre,
                    ),
                    const SizedBox(height: TablTokens.espaceM),
                    Text(
                      'On a envoyé un lien de confirmation à '
                      '${widget.email}. Cette page se met à jour toute '
                      'seule dès que tu l\'as confirmé.',
                      textAlign: TextAlign.center,
                      style: TablTokens.corps.copyWith(
                        color: TablTokens.texteDoux,
                      ),
                    ),
                    const SizedBox(height: TablTokens.espaceXl),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: TablTokens.primaire,
                      ),
                    ),
                    const SizedBox(height: TablTokens.espaceXl),
                    TablBoutonTexte(
                      libelle: 'Déjà confirmé ? Vérifier maintenant',
                      onPresse: _verifier,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: TablTokens.espaceS,
              left: TablTokens.espaceM,
              child: TablBoutonRetour(
                onPresse: () => revenirVersAccueilOuSecours(
                  context,
                  widget.authService,
                  widget.abonnementService,
                  widget.souvenirService,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
