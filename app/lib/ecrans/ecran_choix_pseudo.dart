import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_principal.dart';

/// Affiché après un premier login Apple/Google : ces comptes n'ont pas de
/// pseudo (contrairement à l'inscription par e-mail, qui le demande dès le
/// départ). Le compte Supabase existe déjà — il ne manque que le profil
/// public.
class EcranChoixPseudo extends StatefulWidget {
  const EcranChoixPseudo({
    super.key,
    required this.authService,
    required this.abonnementService,
    required this.souvenirService,
    required this.id,
    required this.email,
  });

  final AuthService authService;
  final AbonnementService abonnementService;
  final SouvenirService souvenirService;
  final String id;
  final String email;

  @override
  State<EcranChoixPseudo> createState() => _EcranChoixPseudoState();
}

class _EcranChoixPseudoState extends State<EcranChoixPseudo> {
  final _pseudo = TextEditingController();

  String? _erreurPseudo;
  bool _enCours = false;

  @override
  void dispose() {
    _pseudo.dispose();
    super.dispose();
  }

  Future<void> _continuer() async {
    final erreurPseudo = Validation.pseudo(_pseudo.text);
    setState(() => _erreurPseudo = erreurPseudo);
    if (erreurPseudo != null) return;

    setState(() => _enCours = true);
    try {
      final utilisateur = await widget.authService.completerProfil(
        id: widget.id,
        email: widget.email,
        pseudo: _pseudo.text.trim(),
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
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EnveloppeFormulaire(
      titre: 'Choisis ton pseudo',
      sousTitre: "C'est comme ça que tes amis te retrouveront sur Tabl.",
      children: [
        TablChampTexte(
          libelle: 'Nom d\'utilisateur',
          controleur: _pseudo,
          indication: 'camille',
          erreur: _erreurPseudo,
          actionClavier: TextInputAction.done,
          iconePrefixe: Icons.person_outline_rounded,
          actif: !_enCours,
          onChanged: (_) {
            if (_erreurPseudo != null) setState(() => _erreurPseudo = null);
          },
          onSoumis: (_) => _continuer(),
        ),
        const SizedBox(height: TablTokens.espaceXl),
        TablBouton(
          libelle: 'Continuer',
          enCours: _enCours,
          onPresse: _continuer,
        ),
      ],
    );
  }
}
