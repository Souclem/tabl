import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Ouvre un moment agrandi par-dessus le profil : sa photo vole depuis
/// sa tuile ([cleHero]), le reste arrive en fondu. La croix la renvoie à
/// sa place.
///
/// Les actions sont celles de l'écran qui l'ouvre (réagir, enregistrer…) :
/// la page n'en garde qu'une copie locale pour s'afficher à jour tout de
/// suite, l'écran derrière fait le vrai travail. Les commentaires, eux,
/// se lisent et s'écrivent ici même, sous le moment.
Future<void> ouvrirPageMoment(
  BuildContext context, {
  required SouvenirFeed souvenir,
  required Object cleHero,
  required SouvenirService souvenirService,
  required Future<void> Function(SouvenirFeed) onReagir,
  required void Function(SouvenirFeed) onOuvrirLieu,
  Future<void> Function(SouvenirFeed)? onEnregistrer,
  void Function(SouvenirFeed)? onOptions,
  void Function(PersonnePresente)? onOuvrirPersonne,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 480),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, _, _) => _PageMoment(
        souvenir: souvenir,
        cleHero: cleHero,
        souvenirService: souvenirService,
        onReagir: onReagir,
        onOuvrirLieu: onOuvrirLieu,
        onEnregistrer: onEnregistrer,
        onOptions: onOptions,
        onOuvrirPersonne: onOuvrirPersonne,
      ),
      // Le fond se pose vite, pendant que la photo vole encore : le
      // profil derrière ne se mélange jamais au texte du moment.
      transitionsBuilder: (_, animation, _, page) => FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0, 0.45, curve: Curves.easeOut),
        ),
        child: page,
      ),
    ),
  );
}

class _PageMoment extends StatefulWidget {
  const _PageMoment({
    required this.souvenir,
    required this.cleHero,
    required this.souvenirService,
    required this.onReagir,
    required this.onOuvrirLieu,
    required this.onEnregistrer,
    required this.onOptions,
    required this.onOuvrirPersonne,
  });

  final SouvenirFeed souvenir;
  final Object cleHero;
  final SouvenirService souvenirService;
  final Future<void> Function(SouvenirFeed) onReagir;
  final void Function(SouvenirFeed) onOuvrirLieu;
  final Future<void> Function(SouvenirFeed)? onEnregistrer;
  final void Function(SouvenirFeed)? onOptions;
  final void Function(PersonnePresente)? onOuvrirPersonne;

  @override
  State<_PageMoment> createState() => _PageMomentState();
}

class _PageMomentState extends State<_PageMoment> {
  late SouvenirFeed _souvenir = widget.souvenir;

  /// `null` pendant le chargement.
  List<Commentaire>? _commentaires;

  @override
  void initState() {
    super.initState();
    _chargerCommentaires();
  }

  Future<void> _chargerCommentaires() async {
    try {
      final commentaires = await widget.souvenirService.commentaires(
        _souvenir.id,
      );
      if (!mounted) return;
      setState(() => _commentaires = commentaires);
    } catch (e) {
      debugPrint('PageMoment: commentaires : $e');
      if (!mounted) return;
      setState(() => _commentaires = const []);
      afficherMessage(context, messageErreurGenerique);
    }
  }

  Future<bool> _commenter(String texte) async {
    try {
      await widget.souvenirService.commenter(_souvenir.id, texte);
    } catch (_) {
      if (mounted) afficherMessage(context, messageErreurGenerique);
      return false;
    }
    await _chargerCommentaires();
    return true;
  }

  /// Optimiste : le commentaire disparaît tout de suite, et revient si
  /// la suppression échoue.
  Future<void> _supprimerCommentaire(Commentaire commentaire) async {
    final avant = _commentaires;
    if (avant == null) return;
    setState(() {
      _commentaires = [
        for (final c in avant)
          if (c.id != commentaire.id) c,
      ];
    });
    try {
      await widget.souvenirService.supprimerCommentaire(commentaire.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _commentaires = avant);
      afficherMessage(context, messageErreurGenerique);
    }
  }

  void _reagir() {
    final avant = _souvenir;
    final reagit = !avant.jaiReagi;
    setState(() {
      _souvenir = avant.copierAvec(
        jaiReagi: reagit,
        nombreReactions: avant.nombreReactions + (reagit ? 1 : -1),
      );
    });
    widget.onReagir(avant);
  }

  void _enregistrer() {
    final avant = _souvenir;
    setState(() => _souvenir = avant.copierAvec(estEnvie: !avant.estEnvie));
    widget.onEnregistrer!(avant);
  }

  @override
  Widget build(BuildContext context) {
    final s = _souvenir;
    final presents = s.presents;
    final ouvrirPersonne = widget.onOuvrirPersonne;
    final commentaires = _commentaires;
    // Un Scaffold à elle : les messages (« Audience mise à jour. »)
    // s'affichent par-dessus le moment agrandi, pas sous lui.
    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: TablVisionneuseMoment(
        cleHero: widget.cleHero,
        photoUrl: s.photoUrl,
        autresPhotosUrls: s.autresPhotosUrls,
        estSouvenir: s.estSouvenir,
        restaurantNom: s.restaurantNom,
        details: detailsMoment(s),
        emojiEmotion: s.emotion?.emoji,
        bulles: [
          for (final p in presents)
            BullePersonne(
              pseudo: nomPersonne(p),
              photoUrl: p.photoUrl,
              onPresse: p.estMoi || ouvrirPersonne == null
                  ? null
                  : () => ouvrirPersonne(p),
            ),
        ],
        avecQui: avecQuiMoment(s),
        legende: legendeAffichee(s.legende),
        impressions: s.impressions,
        jaiReagi: s.jaiReagi,
        libelleReactions: libelleReactionsSouvenir(s),
        enregistre: s.estEnvie,
        audienceRestreinte: s.audienceRestreinte,
        onReagir: _reagir,
        // Pendant le chargement, le nombre déjà connu : le titre ne
        // saute pas quand la liste arrive.
        titreCommentaires: titreCommentaires(
          commentaires?.length ?? s.nombreCommentaires,
        ),
        commentaires: commentaires == null
            ? null
            : [
                for (final c in commentaires)
                  CommentaireAffiche(
                    pseudo: c.auteurPseudo,
                    photoUrl: c.auteurPhotoUrl,
                    texte: c.texte,
                    quand: dateLisibleCommentaire(c.creeLe),
                    onSupprimer: c.estLeMien
                        ? () => _supprimerCommentaire(c)
                        : null,
                  ),
              ],
        onEnvoyerCommentaire: _commenter,
        onOuvrirLieu: () => widget.onOuvrirLieu(s),
        onEnregistrer: widget.onEnregistrer == null ? null : _enregistrer,
        onOptions: widget.onOptions == null ? null : () => widget.onOptions!(s),
        onFermer: () => Navigator.of(context).pop(),
      ),
    );
  }
}
