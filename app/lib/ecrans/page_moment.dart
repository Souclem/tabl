import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'actions_publications.dart';
import 'gestion_commentaires.dart';

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

class _PageMomentState extends State<_PageMoment>
    with GestionCommentaires<_PageMoment> {
  late SouvenirFeed _souvenir = widget.souvenir;

  @override
  SouvenirService get souvenirService => widget.souvenirService;

  @override
  String get souvenirCommenteId => widget.souvenir.id;

  @override
  void Function(String profilId, String pseudo)? get ouvrirProfilAuteur {
    final ouvrir = widget.onOuvrirPersonne;
    if (ouvrir == null) return null;
    return (id, pseudo) => ouvrir(PersonnePresente(id: id, pseudo: pseudo));
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
    final c = TablCouleurs.of(context);
    final presents = s.presents;
    final ouvrirPersonne = widget.onOuvrirPersonne;
    // Un Scaffold à elle : les messages (« Audience mise à jour. »)
    // s'affichent par-dessus le moment agrandi, pas sous lui.
    return Scaffold(
      backgroundColor: c.fond,
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
        bullesReactions: bullesQuiOntAime(s),
        enregistre: s.estEnvie,
        audienceRestreinte: s.audienceRestreinte,
        onReagir: _reagir,
        commentaires: TablCommentairesMoment(
          titre: titreDesCommentaires(s.nombreCommentaires),
          fils: filsAffiches,
          saisie: champCommentaire,
        ),
        onCommenter: focusCommentaire.requestFocus,
        onOuvrirLieu: () => widget.onOuvrirLieu(s),
        onEnregistrer: widget.onEnregistrer == null ? null : _enregistrer,
        onOptions: widget.onOptions == null ? null : () => widget.onOptions!(s),
        onFermer: () => Navigator.of(context).pop(),
      ),
    );
  }
}
