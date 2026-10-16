import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import '../navigation/connexion_oauth.dart';
import '../navigation/transitions.dart';
import 'ecran_accueil.dart';
import 'ecran_attente_confirmation.dart';
import 'ecran_choix_pseudo.dart';
import 'ecran_connexion.dart';
import 'ecran_principal.dart';

/// Écran de création de compte.
class EcranInscription extends StatefulWidget {
  const EcranInscription({
    super.key,
    required this.authService,
    required this.abonnementService,
    required this.souvenirService,
  });

  final AuthService authService;
  final AbonnementService abonnementService;
  final SouvenirService souvenirService;

  @override
  State<EcranInscription> createState() => _EcranInscriptionState();
}

class _EcranInscriptionState extends State<EcranInscription> {
  final _pseudo = TextEditingController();
  final _email = TextEditingController();
  final _motDePasse = TextEditingController();
  final _confirmationMotDePasse = TextEditingController();

  String? _erreurPseudo;
  String? _erreurEmail;
  String? _erreurMotDePasse;
  String? _erreurConfirmation;
  bool _enCours = false;
  bool _motDePasseVisible = false;

  @override
  void dispose() {
    _pseudo.dispose();
    _email.dispose();
    _motDePasse.dispose();
    _confirmationMotDePasse.dispose();
    super.dispose();
  }

  Future<void> _sInscrire() async {
    final erreurPseudo = Validation.pseudo(_pseudo.text);
    final erreurEmail = Validation.email(_email.text);
    final erreurMotDePasse = Validation.motDePasse(_motDePasse.text);
    final erreurConfirmation = Validation.confirmationMotDePasse(
      _motDePasse.text,
      _confirmationMotDePasse.text,
    );

    setState(() {
      _erreurPseudo = erreurPseudo;
      _erreurEmail = erreurEmail;
      _erreurMotDePasse = erreurMotDePasse;
      _erreurConfirmation = erreurConfirmation;
    });

    final valide =
        erreurPseudo == null &&
        erreurEmail == null &&
        erreurMotDePasse == null &&
        erreurConfirmation == null;
    if (!valide) return;

    setState(() => _enCours = true);
    try {
      final email = _email.text.trim();
      final motDePasse = _motDePasse.text;
      final resultat = await widget.authService.inscription(
        email: email,
        motDePasse: motDePasse,
        pseudo: _pseudo.text.trim(),
      );
      if (!mounted) return;
      switch (resultat) {
        case InscriptionReussie(:final utilisateur):
          Navigator.of(context).pushReplacement(
            EcranPrincipal.route(
              authService: widget.authService,
              abonnementService: widget.abonnementService,
              souvenirService: widget.souvenirService,
              utilisateur: utilisateur,
            ),
          );
        case InscriptionEnAttenteConfirmation():
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => EcranAttenteConfirmation(
                authService: widget.authService,
                abonnementService: widget.abonnementService,
                souvenirService: widget.souvenirService,
                email: email,
                motDePasse: motDePasse,
              ),
            ),
          );
      }
    } on ErreurAuth catch (e) {
      if (!mounted) return;
      afficherMessage(context, e.message);
    } catch (_) {
      // Réseau, serveur... : pas une ErreurAuth, mais l'utilisateur doit
      // quand même être prévenu plutôt que de voir le bouton s'arrêter
      // sans explication.
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  /// Sign in with Apple demande l'Apple Developer Program (payant) : pas
  /// encore actif sur ce projet. Le bouton reste honnête plutôt que de
  /// planter sur une capability absente — voir AuthServiceSupabase.
  /// connexionApple, déjà implémentée, prête à être branchée le jour où
  /// le compte payant est actif.
  void _afficherAppleBientotDisponible() {
    afficherMessage(context, 'Bientôt disponible.');
  }

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

  void _allerVersConnexion() {
    Navigator.of(context).pushReplacement(
      remplacerFormulaire(
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
    return EnveloppeFormulaire(
      titre: 'Créer un compte',
      sousTitre: 'Tabl est privé par défaut : tu choisis qui voit ce que tu publies.',
      onRetour: () => revenirVersAccueilOuSecours(
        context,
        widget.authService,
        widget.abonnementService,
        widget.souvenirService,
      ),
      children: [
        TablChampTexte(
          libelle: "Nom d'utilisateur",
          controleur: _pseudo,
          indication: 'camille',
          erreur: _erreurPseudo,
          actionClavier: TextInputAction.next,
          iconePrefixe: Icons.person_outline_rounded,
          actif: !_enCours,
          onChanged: (_) {
            if (_erreurPseudo != null) setState(() => _erreurPseudo = null);
          },
        ),
        const SizedBox(height: TablTokens.espaceL),
        TablChampTexte(
          libelle: 'E-mail',
          controleur: _email,
          indication: 'toi@exemple.com',
          erreur: _erreurEmail,
          typeClavier: TextInputType.emailAddress,
          actionClavier: TextInputAction.next,
          iconePrefixe: Icons.mail_outline_rounded,
          actif: !_enCours,
          onChanged: (_) {
            if (_erreurEmail != null) setState(() => _erreurEmail = null);
          },
        ),
        const SizedBox(height: TablTokens.espaceL),
        TablChampMotDePasse(
          libelle: 'Mot de passe',
          controleur: _motDePasse,
          indication: '${Validation.longueurMinMotDePasse} caractères minimum',
          erreur: _erreurMotDePasse,
          visible: _motDePasseVisible,
          onToggleVisible: () =>
              setState(() => _motDePasseVisible = !_motDePasseVisible),
          actif: !_enCours,
          onChanged: (_) {
            if (_erreurMotDePasse != null) {
              setState(() => _erreurMotDePasse = null);
            }
          },
        ),
        const SizedBox(height: TablTokens.espaceL),
        TablChampMotDePasse(
          libelle: 'Confirmer le mot de passe',
          controleur: _confirmationMotDePasse,
          erreur: _erreurConfirmation,
          visible: _motDePasseVisible,
          onToggleVisible: () =>
              setState(() => _motDePasseVisible = !_motDePasseVisible),
          actif: !_enCours,
          onChanged: (_) {
            if (_erreurConfirmation != null) {
              setState(() => _erreurConfirmation = null);
            }
          },
          onSoumis: (_) => _sInscrire(),
        ),
        const SizedBox(height: TablTokens.espaceXl),
        TablBouton(
          libelle: 'Créer mon compte',
          enCours: _enCours,
          onPresse: _sInscrire,
        ),
        const SizedBox(height: TablTokens.espaceL),
        const TablSeparateurTexte(texte: 'Ou'),
        const SizedBox(height: TablTokens.espaceL),
        TablBoutonsAuthTierce(
          onPresseApple: _enCours ? null : _afficherAppleBientotDisponible,
          onPresseGoogle: _enCours ? null : _connexionGoogle,
        ),
        const SizedBox(height: TablTokens.espaceL),
        TablLienBasDePage(
          question: 'Déjà un compte ?',
          libelleAction: 'Se connecter',
          onAction: _enCours ? null : _allerVersConnexion,
        ),
        const SizedBox(height: TablTokens.espaceM),
        Text(
          "En créant un compte, vous acceptez nos Conditions d'utilisation "
          'et notre Politique de confidentialité.',
          textAlign: TextAlign.center,
          style: TablTokens.legende,
        ),
      ],
    );
  }
}
