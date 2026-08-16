import 'package:flutter/material.dart';
import 'package:tabl_core/tabl_core.dart';
import 'package:tabl_ui/tabl_ui.dart';

/// Écran de création de compte.
class EcranInscription extends StatefulWidget {
  const EcranInscription({super.key, required this.authService});

  final AuthService authService;

  @override
  State<EcranInscription> createState() => _EcranInscriptionState();
}

class _EcranInscriptionState extends State<EcranInscription> {
  final _pseudo = TextEditingController();
  final _email = TextEditingController();
  final _motDePasse = TextEditingController();
  final _confirmation = TextEditingController();

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
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _sInscrire() async {
    final erreurPseudo = Validation.pseudo(_pseudo.text);
    final erreurEmail = Validation.email(_email.text);
    final erreurMotDePasse = Validation.motDePasse(_motDePasse.text);
    final erreurConfirmation = Validation.confirmationMotDePasse(
      _motDePasse.text,
      _confirmation.text,
    );

    setState(() {
      _erreurPseudo = erreurPseudo;
      _erreurEmail = erreurEmail;
      _erreurMotDePasse = erreurMotDePasse;
      _erreurConfirmation = erreurConfirmation;
    });

    final valide = erreurPseudo == null &&
        erreurEmail == null &&
        erreurMotDePasse == null &&
        erreurConfirmation == null;
    if (!valide) return;

    setState(() => _enCours = true);
    try {
      await widget.authService.inscription(
        email: _email.text.trim(),
        motDePasse: _motDePasse.text,
        pseudo: _pseudo.text.trim(),
      );
      if (!mounted) return;
      _afficherMessage('Compte créé.');
    } on ErreurAuth catch (e) {
      if (!mounted) return;
      _afficherMessage(e.message);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  void _afficherMessage(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  @override
  Widget build(BuildContext context) {
    return EnveloppeFormulaire(
      titre: 'Créer un compte',
      sousTitre: 'Tabl est privé : seuls tes amis voient ce que tu publies.',
      children: [
        TablChampTexte(
          libelle: 'Pseudo',
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
        TablChampTexte(
          libelle: 'Mot de passe',
          controleur: _motDePasse,
          indication: '${Validation.longueurMinMotDePasse} caractères minimum',
          erreur: _erreurMotDePasse,
          masque: !_motDePasseVisible,
          actionClavier: TextInputAction.next,
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
        ),
        const SizedBox(height: TablTokens.espaceL),
        TablChampTexte(
          libelle: 'Confirmer le mot de passe',
          controleur: _confirmation,
          erreur: _erreurConfirmation,
          masque: !_motDePasseVisible,
          actionClavier: TextInputAction.done,
          iconePrefixe: Icons.lock_outline_rounded,
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Déjà un compte ?', style: TablTokens.legende),
            TablBoutonTexte(
              libelle: 'Se connecter',
              onPresse: _enCours ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }
}
