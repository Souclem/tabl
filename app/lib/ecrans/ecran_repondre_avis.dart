import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Répondre à « Tu me conseilles d'y aller ? », d'après le prototype : la
/// question reçue, trois réponses en un toucher, un mot si on veut, et
/// c'est envoyé — en privé, seul celui qui demande le lira. Se ferme sur
/// `true` une fois la réponse envoyée.
class EcranRepondreAvis extends StatefulWidget {
  const EcranRepondreAvis({
    super.key,
    required this.avisService,
    required this.demandeId,
    required this.demandeur,
    required this.question,
    this.demandeurPhotoUrl,
    this.restaurantNom,
  });

  final AvisService avisService;
  final String demandeId;

  /// "Martin".
  final String demandeur;
  final String? demandeurPhotoUrl;

  /// "Tu me conseilles d'aller chez Osteria Bella ?".
  final String question;
  final String? restaurantNom;

  @override
  State<EcranRepondreAvis> createState() => _EcranRepondreAvisState();
}

class _EcranRepondreAvisState extends State<EcranRepondreAvis> {
  ReponseAvis? _reponse;
  final _mot = TextEditingController();
  bool _enCours = false;

  @override
  void dispose() {
    _mot.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    final reponse = _reponse;
    if (reponse == null) return;
    setState(() => _enCours = true);
    try {
      await widget.avisService.repondre(
        widget.demandeId,
        reponse,
        mot: _mot.text,
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      Navigator.of(context).pop(true);
      afficherMessage(context, 'Réponse envoyée à ${widget.demandeur}.');
    } catch (e) {
      debugPrint('EcranRepondreAvis: $e');
      if (!mounted) return;
      setState(() => _enCours = false);
      afficherMessage(context, messageErreurGenerique);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final reponse = _reponse;
    return Scaffold(
      backgroundColor: c.fond,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TablTokens.espaceM,
                TablTokens.espaceS,
                TablTokens.espaceM,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TablBoutonRetour(
                  onPresse: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  TablTokens.espaceL - 4,
                  TablTokens.espaceL,
                  TablTokens.espaceL - 4,
                  TablTokens.espaceL,
                ),
                children: [
                  Row(
                    children: [
                      TablAvatar(
                        pseudo: widget.demandeur,
                        photoUrl: widget.demandeurPhotoUrl,
                        rayon: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${widget.demandeur} vous demande',
                          style: c.corps.copyWith(
                            fontWeight: FontWeight.w600,
                            color: c.texte,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: TablTokens.espaceM),
                  Text(
                    '« ${widget.question} »',
                    style: c.titreAffichage.copyWith(
                      fontSize: 26,
                      height: 1.25,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: TablTokens.espaceXl),
                  Text(
                    'Répondez en un toucher. Votre réponse reste privée.',
                    style: c.legende.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: TablTokens.espaceM - 4),
                  for (final r in ReponseAvis.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TablChoixReponse(
                        emoji: r.emoji,
                        libelle: r.libelle,
                        choisie: reponse == r,
                        onPresse: () {
                          HapticFeedback.selectionClick();
                          setState(() => _reponse = r);
                        },
                      ),
                    ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    alignment: Alignment.topCenter,
                    child: reponse == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(
                              top: TablTokens.espaceM,
                            ),
                            child: TablChampTexte(
                              libelle: 'Ajouter un mot ?',
                              controleur: _mot,
                              indication: reponse == ReponseAvis.depend
                                  ? 'Une phrase suffit à expliquer le « ça dépend »'
                                  : 'Facultatif',
                              lignes: 2,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TablTokens.espaceL - 4,
                TablTokens.espaceS,
                TablTokens.espaceL - 4,
                TablTokens.espaceM,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TablBouton(
                    libelle: 'Envoyer ma réponse',
                    enCours: _enCours,
                    onPresse: reponse == null ? null : _envoyer,
                  ),
                  TablBoutonTexte(
                    libelle: 'Plus tard',
                    onPresse: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
