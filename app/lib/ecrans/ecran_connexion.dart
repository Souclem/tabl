import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import '../navigation/connexion_oauth.dart';
import '../navigation/transitions.dart';
import 'ecran_accueil.dart';
import 'ecran_inscription.dart';
import 'ecran_principal.dart';

/// Écran de connexion.
///
/// C'est ici que le métier et le visuel se rencontrent : on demande les
/// règles à `services/`, on affiche avec `widgets/`.
class EcranConnexion extends StatefulWidget {
  const EcranConnexion({
    super.key,
    required this.authService,
    required this.abonnementService,
    required this.souvenirService,
  });

  final AuthService authService;
  final AbonnementService abonnementService;
  final SouvenirService souvenirService;

  @override
  State<EcranConnexion> createState() => _EcranConnexionState();
}

class _EcranConnexionState extends State<EcranConnexion> {
  final _email = TextEditingController();
  final _motDePasse = TextEditingController();

  String? _erreurEmail;
  String? _erreurMotDePasse;
  bool _enCours = false;
  bool _motDePasseVisible = false;

  @override
  void dispose() {
    _email.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    // Validation : les règles viennent de services/auth/validation.dart.
    final erreurEmail = Validation.email(_email.text);
    final erreurMotDePasse = Validation.motDePasseRempli(_motDePasse.text);

    setState(() {
      _erreurEmail = erreurEmail;
      _erreurMotDePasse = erreurMotDePasse;
    });

    if (erreurEmail != null || erreurMotDePasse != null) return;

    setState(() => _enCours = true);
    try {
      final utilisateur = await widget.authService.connexion(
        email: _email.text.trim(),
        motDePasse: _motDePasse.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        EcranPrincipal.route(
          authService: widget.authService,
          abonnementService: widget.abonnementService,
          souvenirService: widget.souvenirService,
          utilisateur: utilisateur,
        ),
      );
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

  void _allerVersInscription() {
    Navigator.of(context).pushReplacement(
      remplacerFormulaire(
        EcranInscription(
          authService: widget.authService,
          abonnementService: widget.abonnementService,
          souvenirService: widget.souvenirService,
        ),
      ),
    );
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
      // Pas de profil = pas encore de compte Tabl : la connexion ne crée
      // pas de compte à la volée (contrairement à l'inscription), on
      // renvoie explicitement vers l'inscription plutôt que de laisser
      // entrer quelqu'un qui n'a jamais créé de compte.
      case ProfilAConfigurer():
        afficherMessage(
          context,
          "Aucun compte Tabl n'est associé à ce compte. Crée d'abord un "
          'compte.',
        );
        Navigator.of(context).pushReplacement(
          remplacerFormulaire(
            EcranInscription(
              authService: widget.authService,
              abonnementService: widget.abonnementService,
              souvenirService: widget.souvenirService,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return EnveloppeFormulaire(
      titre: 'Bon retour',
      sousTitre: 'Connecte-toi pour retrouver les tables de tes amis.',
      onRetour: () => revenirVersAccueilOuSecours(
        context,
        widget.authService,
        widget.abonnementService,
        widget.souvenirService,
      ),
      children: [
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
          onSoumis: (_) => _seConnecter(),
        ),
        const SizedBox(height: TablTokens.espaceXl),
        TablBouton(
          libelle: 'Se connecter',
          enCours: _enCours,
          onPresse: _seConnecter,
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
          question: 'Pas encore de compte ?',
          libelleAction: "S'inscrire",
          onAction: _enCours ? null : _allerVersInscription,
        ),
      ],
    );
  }
}
