import 'package:flutter/material.dart';
import 'package:tabl_core/tabl_core.dart';
import 'package:tabl_ui/tabl_ui.dart';

import 'ecran_inscription.dart';

/// Écran de connexion.
///
/// C'est ici que le métier et le visuel se rencontrent : on demande les
/// règles à `tabl_core`, on affiche avec `tabl_ui`.
class EcranConnexion extends StatefulWidget {
  const EcranConnexion({super.key, required this.authService});

  final AuthService authService;

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
    // Validation : les règles viennent de tabl_core.
    final erreurEmail = Validation.email(_email.text);
    final erreurMotDePasse = Validation.motDePasseRempli(_motDePasse.text);

    setState(() {
      _erreurEmail = erreurEmail;
      _erreurMotDePasse = erreurMotDePasse;
    });

    if (erreurEmail != null || erreurMotDePasse != null) return;

    setState(() => _enCours = true);
    try {
      await widget.authService.connexion(
        email: _email.text.trim(),
        motDePasse: _motDePasse.text,
      );
      if (!mounted) return;
      _afficherMessage('Connecté.');
    } on ErreurAuth catch (e) {
      if (!mounted) return;
      _afficherMessage(e.message);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  void _allerVersInscription() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranInscription(authService: widget.authService),
      ),
    );
  }

  void _afficherMessage(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return EnveloppeFormulaire(
      titre: 'Bon retour',
      sousTitre: 'Connecte-toi pour retrouver les tables de tes amis.',
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
        TablChampTexte(
          libelle: 'Mot de passe',
          controleur: _motDePasse,
          erreur: _erreurMotDePasse,
          masque: !_motDePasseVisible,
          actionClavier: TextInputAction.done,
          iconePrefixe: Icons.lock_outline_rounded,
          actif: !_enCours,
          suffixe: IconButton(
            icon: Icon(
              _motDePasseVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
              color: TablTokens.texteDoux,
            ),
            onPressed: () =>
                setState(() => _motDePasseVisible = !_motDePasseVisible),
          ),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Pas encore de compte ?', style: TablTokens.legende),
            TablBoutonTexte(
              libelle: "S'inscrire",
              onPresse: _enCours ? null : _allerVersInscription,
            ),
          ],
        ),
      ],
    );
  }
}
