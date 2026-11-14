import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Le choix fait dans « Brouillons » : le [brouillon] à reprendre, ou
/// `null` pour un nouveau moment.
typedef ChoixBrouillon = ({Brouillon? brouillon});

/// « + » quand des moments sont en cours : la feuille « Brouillons » (sombre,
/// comme la caméra) liste les [aReprendre], puis « Nouveau moment » (grisé
/// à [nombreMaxBrouillons]). La corbeille d'une ligne supprime le
/// brouillon, après confirmation. Rend `null` si la feuille est fermée sans
/// choix.
Future<ChoixBrouillon?> ouvrirFeuilleBrouillons(
  BuildContext context, {
  required BrouillonsLocaux brouillons,
  required List<Brouillon> aReprendre,
  DateTime Function()? maintenant,
}) {
  const c = TablCouleurs.sombre;
  return showModalBottomSheet<ChoixBrouillon>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.fond,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _FeuilleBrouillons(
      brouillons: brouillons,
      aReprendre: aReprendre,
      maintenant: maintenant ?? DateTime.now,
    ),
  );
}

class _FeuilleBrouillons extends StatefulWidget {
  const _FeuilleBrouillons({
    required this.brouillons,
    required this.aReprendre,
    required this.maintenant,
  });

  final BrouillonsLocaux brouillons;
  final List<Brouillon> aReprendre;
  final DateTime Function() maintenant;

  @override
  State<_FeuilleBrouillons> createState() => _FeuilleBrouillonsState();
}

class _FeuilleBrouillonsState extends State<_FeuilleBrouillons> {
  late final _liste = [...widget.aReprendre];

  Future<void> _supprimer(String id) async {
    final brouillon = _liste.firstWhere((b) => b.id == id);
    final c = TablCouleurs.of(context);
    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexteDialogue) => AlertDialog(
        backgroundColor: c.surface,
        title: const Text('Supprimer ce brouillon ?'),
        content: Text(detailSuppressionBrouillon(brouillon)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexteDialogue).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexteDialogue).pop(true),
            child: Text('Supprimer', style: TextStyle(color: c.erreur)),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    try {
      await widget.brouillons.supprimerBrouillon(id);
    } catch (e) {
      debugPrint('FeuilleBrouillons: suppression : $e');
      if (mounted) afficherMessage(context, messageErreurGenerique);
      return;
    }
    if (mounted) setState(() => _liste.removeWhere((b) => b.id == id));
  }

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    final maintenant = widget.maintenant();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.only(top: 8, bottom: 14),
                decoration: BoxDecoration(
                  color: c.texte.withValues(alpha: 0.26),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Text(
                'Brouillons',
                style: TablTokens.policeCreation.copyWith(
                  fontSize: 17,
                  letterSpacing: -0.17,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 16),
                child: TablListeBrouillons(
                  brouillons: [
                    for (final b in _liste)
                      (
                        id: b.id,
                        image: widget.brouillons.imagePhoto(
                          b.id,
                          b.photos.first.id,
                        ),
                        titre: titreBrouillon(b),
                        detail: detailBrouillon(b, maintenant: maintenant),
                      ),
                  ],
                  libelleNouveau: 'Nouveau moment',
                  libelleSupprimer: 'Supprimer ce brouillon',
                  libelleLimite: peutCommencerUnMoment(_liste)
                      ? null
                      : libelleLimiteBrouillons,
                  onReprendre: (id) => Navigator.of(
                    context,
                  ).pop((brouillon: _liste.firstWhere((b) => b.id == id))),
                  onSupprimer: _supprimer,
                  onNouveau: () => Navigator.of(context).pop((brouillon: null)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
