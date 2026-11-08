import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'gestion_commentaires.dart';

/// Les commentaires d'un moment dans une feuille qui monte par-dessus
/// l'écran, comme sur Instagram : on les lit, on répond, on aime, sans
/// quitter le Feed. [onNombre] suit le nombre de commentaires à chaque
/// changement.
Future<void> ouvrirFeuilleCommentaires(
  BuildContext context, {
  required SouvenirService souvenirService,
  required SouvenirFeed souvenir,
  void Function(String profilId, String pseudo)? onOuvrirProfil,
  ValueChanged<int>? onNombre,
}) {
  final c = TablCouleurs.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.surface,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _FeuilleCommentaires(
      souvenirService: souvenirService,
      souvenir: souvenir,
      onOuvrirProfil: onOuvrirProfil,
      onNombre: onNombre,
    ),
  );
}

class _FeuilleCommentaires extends StatefulWidget {
  const _FeuilleCommentaires({
    required this.souvenirService,
    required this.souvenir,
    required this.onOuvrirProfil,
    required this.onNombre,
  });

  final SouvenirService souvenirService;
  final SouvenirFeed souvenir;
  final void Function(String profilId, String pseudo)? onOuvrirProfil;
  final ValueChanged<int>? onNombre;

  @override
  State<_FeuilleCommentaires> createState() => _FeuilleCommentairesState();
}

class _FeuilleCommentairesState extends State<_FeuilleCommentaires>
    with GestionCommentaires<_FeuilleCommentaires> {
  /// La hauteur de la feuille à l'ouverture, en part de l'écran.
  static const _hauteurOuverte = 0.7;

  final _taille = DraggableScrollableController();

  @override
  SouvenirService get souvenirService => widget.souvenirService;

  @override
  String get souvenirCommenteId => widget.souvenir.id;

  @override
  void Function(String profilId, String pseudo)? get ouvrirProfilAuteur =>
      widget.onOuvrirProfil;

  @override
  void commentairesCharges(List<Commentaire> commentaires) =>
      widget.onNombre?.call(commentaires.length);

  @override
  void initState() {
    super.initState();
    focusCommentaire.addListener(_deplierPourEcrire);
  }

  @override
  void dispose() {
    focusCommentaire.removeListener(_deplierPourEcrire);
    _taille.dispose();
    super.dispose();
  }

  /// On écrit : la feuille prend toute la hauteur, la conversation reste
  /// lisible au-dessus du clavier.
  void _deplierPourEcrire() {
    if (!focusCommentaire.hasFocus || !_taille.isAttached) return;
    _taille.animateTo(
      1,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Le champ reste au-dessus du clavier.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        controller: _taille,
        expand: false,
        initialChildSize: _hauteurOuverte,
        minChildSize: 0.3,
        snap: true,
        snapSizes: const [_hauteurOuverte],
        builder: (context, defilement) => TablFeuilleCommentaires(
          controleurDefilement: defilement,
          titre: titreDesCommentaires(widget.souvenir.nombreCommentaires),
          fils: filsAffiches,
          saisie: champCommentaire,
        ),
      ),
    );
  }
}
