import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// « Aide et contact » : un bug, une idée, quelque chose de pas clair…
/// On dit de quoi il s'agit, on écrit, on joint des captures d'écran si
/// on veut ; le message part à l'équipe.
class EcranAide extends StatefulWidget {
  const EcranAide({super.key, required this.retourService});

  final RetourService retourService;

  @override
  State<EcranAide> createState() => _EcranAideState();
}

class _EcranAideState extends State<EcranAide> {
  final _texte = TextEditingController();
  TypeRetour? _type;
  final List<Uint8List> _captures = [];
  bool _envoi = false;
  bool _envoye = false;

  static const _icones = {
    TypeRetour.bug: Icons.bug_report_outlined,
    TypeRetour.idee: Icons.lightbulb_outline_rounded,
    TypeRetour.pasClair: Icons.help_outline_rounded,
    TypeRetour.lieu: Icons.storefront_outlined,
    TypeRetour.signalement: Icons.flag_outlined,
    TypeRetour.autre: Icons.chat_bubble_outline_rounded,
  };

  @override
  void initState() {
    super.initState();
    // Le bouton « Envoyer » s'allume dès qu'il y a quelque chose à envoyer.
    _texte.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  Future<void> _ajouterCaptures() async {
    final restantes = nombreMaxCaptures - _captures.length;
    if (restantes <= 0) return;
    // Assez grandes pour lire le texte d'une capture, sans envoyer des
    // fichiers de plusieurs Mo.
    final fichiers = await ImagePicker().pickMultiImage(
      limit: restantes,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (fichiers.isEmpty) return;
    final octets = await Future.wait([
      for (final f in fichiers.take(restantes)) f.readAsBytes(),
    ]);
    if (!mounted) return;
    setState(() => _captures.addAll(octets));
  }

  Future<void> _envoyer() async {
    final type = _type;
    if (!peutEnvoyerRetour(type, _texte.text)) return;
    FocusScope.of(context).unfocus();
    setState(() => _envoi = true);
    try {
      await widget.retourService.envoyer(
        type: type!,
        texte: _texte.text,
        captures: List.of(_captures),
      );
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _envoye = true;
      });
    } catch (e) {
      debugPrint('EcranAide: $e');
      if (!mounted) return;
      setState(() => _envoi = false);
      afficherMessage(context, messageErreurGenerique);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Scaffold(
      backgroundColor: c.fond,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: _envoye
              ? TablConfirmationEnvoi(
                  key: const ValueKey('merci'),
                  titre: 'Merci !',
                  message:
                      'Ton message est bien arrivé : toute l’équipe va le '
                      'lire.',
                  libelleBouton: 'Revenir',
                  onPresse: () => Navigator.of(context).pop(),
                )
              : _formulaire(),
        ),
      ),
    );
  }

  Widget _formulaire() {
    final c = TablCouleurs.of(context);
    const marge = TablTokens.espaceL - 4;
    return Column(
      key: const ValueKey('formulaire'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TablTokens.espaceM,
            TablTokens.espaceS,
            TablTokens.espaceM,
            0,
          ),
          child: Row(
            children: [
              TablBoutonRetour(onPresse: () => Navigator.of(context).pop()),
              const SizedBox(width: TablTokens.espaceM),
              Text('Aide et contact', style: c.titre),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              marge,
              TablTokens.espaceL,
              marge,
              TablTokens.espaceL,
            ),
            children: [
              Text(
                'Un souci, une idée ?',
                style: c.titreAffichage.copyWith(fontSize: 28),
              ),
              const SizedBox(height: TablTokens.espaceS),
              Text(
                'Écris-nous : toute l’équipe lit chaque message.',
                style: c.corps.copyWith(color: c.texteDoux),
              ),
              const SizedBox(height: TablTokens.espaceL),
              const TablTitreSection(texte: 'De quoi s’agit-il ?'),
              TablGrilleChoix(
                options: [
                  for (final t in TypeRetour.values)
                    OptionChoix(
                      icone: _icones[t]!,
                      libelle: t.libelle,
                      description: t.description,
                    ),
                ],
                index: _type?.index,
                onChoisir: (i) => setState(() => _type = TypeRetour.values[i]),
              ),
              const SizedBox(height: TablTokens.espaceM),
              const TablTitreSection(texte: 'Ton message'),
              TextField(
                controller: _texte,
                minLines: 5,
                maxLines: 10,
                maxLength: longueurMaxRetour,
                textCapitalization: TextCapitalization.sentences,
                style: c.corps,
                cursorColor: c.primaire,
                decoration: InputDecoration(
                  hintText:
                      _type?.invite ??
                      'Choisis d’abord de quoi il s’agit, puis raconte-nous.',
                  hintMaxLines: 3,
                  hintStyle: c.corps.copyWith(color: c.texteDoux),
                  counterStyle: c.legende.copyWith(fontSize: 12),
                  filled: true,
                  fillColor: c.surfaceBasse,
                  contentPadding: const EdgeInsets.all(TablTokens.espaceM),
                  enabledBorder: _bord(c.bordure),
                  focusedBorder: _bord(c.primaire.withValues(alpha: 0.6)),
                ),
              ),
              const SizedBox(height: TablTokens.espaceM),
              const TablTitreSection(texte: 'Captures d’écran'),
              Text(
                'Facultatif, $nombreMaxCaptures au plus. Pour un bug, une '
                'capture vaut souvent mieux qu’un long texte.',
                style: c.legende,
              ),
              const SizedBox(height: 12),
              TablVignettesCaptures(
                images: _captures,
                maximum: nombreMaxCaptures,
                onAjouter: _ajouterCaptures,
                onRetirer: (i) => setState(() => _captures.removeAt(i)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            marge,
            TablTokens.espaceS,
            marge,
            TablTokens.espaceM,
          ),
          child: TablBouton(
            libelle: 'Envoyer',
            enCours: _envoi,
            onPresse: peutEnvoyerRetour(_type, _texte.text) ? _envoyer : null,
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _bord(Color couleur) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(TablTokens.arrondiM),
    borderSide: BorderSide(color: couleur),
  );
}
