import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Ce que partagent la feuille des commentaires (Feed, profils) et le
/// moment agrandi : les commentaires d'un moment rangés en fils, en
/// écrire un ou répondre, en aimer, retirer les siens. Chaque geste se
/// voit tout de suite, et revient en arrière si le réseau échoue.
mixin GestionCommentaires<T extends StatefulWidget> on State<T> {
  SouvenirService get souvenirService;

  /// Le moment commenté.
  String get souvenirCommenteId;

  /// Ouvre le profil d'un auteur ; `null` (par défaut) : les auteurs ne
  /// sont pas touchables.
  void Function(String profilId, String pseudo)? get ouvrirProfilAuteur => null;

  /// Les commentaires viennent d'être (re)chargés.
  void commentairesCharges(List<Commentaire> commentaires) {}

  /// `null` pendant le chargement.
  List<Commentaire>? commentaires;

  final saisieCommentaire = TextEditingController();
  final focusCommentaire = FocusNode();

  /// Le commentaire auquel on répond ; `null` : on commente le moment.
  Commentaire? enReponseA;
  bool envoiCommentaire = false;

  /// Les fils dont les réponses sont dépliées.
  final Set<String> filsOuverts = {};

  @override
  void initState() {
    super.initState();
    chargerCommentaires();
  }

  @override
  void dispose() {
    saisieCommentaire.dispose();
    focusCommentaire.dispose();
    super.dispose();
  }

  Future<void> chargerCommentaires() async {
    try {
      final liste = await souvenirService.commentaires(souvenirCommenteId);
      if (!mounted) return;
      setState(() => commentaires = liste);
      commentairesCharges(liste);
    } catch (e) {
      debugPrint('Commentaires: chargement : $e');
      if (!mounted) return;
      // Sans ça, la liste resterait sur son chargement pour toujours.
      setState(() => commentaires ??= const []);
      afficherMessage(context, messageErreurGenerique);
    }
  }

  /// « Répondre » : la réponse ira dans le fil de [c]. Répondre à une
  /// réponse, c'est répondre au même fil en nommant son auteur.
  void repondreA(Commentaire c) {
    setState(() {
      enReponseA = c;
      filsOuverts.add(c.filId);
    });
    final mention = '@${c.auteurPseudo} ';
    if (c.parentId != null && !saisieCommentaire.text.startsWith(mention)) {
      saisieCommentaire.value = TextEditingValue(
        text: mention + saisieCommentaire.text,
        selection: TextSelection.collapsed(
          offset: mention.length + saisieCommentaire.text.length,
        ),
      );
    }
    focusCommentaire.requestFocus();
  }

  void annulerReponse() => setState(() => enReponseA = null);

  Future<void> envoyerCommentaire() async {
    final texte = saisieCommentaire.text.trim();
    if (texte.isEmpty || envoiCommentaire) return;
    final fil = enReponseA?.filId;
    setState(() => envoiCommentaire = true);
    try {
      await souvenirService.commenter(souvenirCommenteId, texte, parentId: fil);
    } catch (e) {
      debugPrint('Commentaires: envoi : $e');
      if (!mounted) return;
      // Le texte reste dans le champ : rien n'est perdu.
      setState(() => envoiCommentaire = false);
      afficherMessage(context, messageErreurGenerique);
      return;
    }
    if (!mounted) return;
    saisieCommentaire.clear();
    setState(() {
      envoiCommentaire = false;
      enReponseA = null;
      // Sa réponse se voit : son fil est déplié.
      if (fil != null) filsOuverts.add(fil);
    });
    await chargerCommentaires();
  }

  Future<void> basculerJaimeCommentaire(Commentaire c) async {
    final aimer = !c.jaiAime;
    _modifier((l) => apresJaimeCommentaire(l, c.id, aimer: aimer));
    try {
      await souvenirService.basculerJaimeCommentaire(c.id, aimer: aimer);
    } catch (e) {
      debugPrint('Commentaires: j\'aime : $e');
      if (!mounted) return;
      _modifier((l) => apresJaimeCommentaire(l, c.id, aimer: !aimer));
      afficherMessage(context, messageErreurGenerique);
    }
  }

  /// Retire son commentaire, et ses réponses avec lui — après
  /// confirmation s'il en a.
  Future<void> supprimerCommentaire(Commentaire c) async {
    final avant = commentaires;
    if (avant == null) return;
    final aDesReponses = avant.any((r) => r.parentId == c.id);
    if (aDesReponses && !await _confirmerSuppression()) return;
    if (!mounted) return;
    setState(() {
      commentaires = [
        for (final x in avant)
          if (x.id != c.id && x.parentId != c.id) x,
      ];
      if (enReponseA?.filId == c.id || enReponseA?.id == c.id) {
        enReponseA = null;
      }
    });
    commentairesCharges(commentaires!);
    try {
      await souvenirService.supprimerCommentaire(c.id);
    } catch (e) {
      debugPrint('Commentaires: suppression : $e');
      if (!mounted) return;
      setState(() => commentaires = avant);
      commentairesCharges(avant);
      afficherMessage(context, messageErreurGenerique);
    }
  }

  Future<bool> _confirmerSuppression() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexteDialogue) => AlertDialog(
        backgroundColor: TablTokens.surface,
        title: const Text('Supprimer ce commentaire ?'),
        content: const Text('Ses réponses partiront avec lui.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexteDialogue).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexteDialogue).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: TablTokens.erreur),
            ),
          ),
        ],
      ),
    );
    return confirme ?? false;
  }

  void _modifier(List<Commentaire> Function(List<Commentaire>) changement) {
    final actuels = commentaires;
    if (actuels == null) return;
    setState(() => commentaires = changement(actuels));
  }

  /// "3 commentaires" ; pendant le chargement, d'après le nombre déjà
  /// [connu] : le titre ne saute pas quand la liste arrive.
  String titreDesCommentaires(int connu) =>
      titreCommentaires(commentaires?.length ?? connu);

  /// Les fils prêts à afficher ; `null` pendant le chargement.
  List<FilAffiche>? get filsAffiches {
    final liste = commentaires;
    if (liste == null) return null;
    final ouvrirProfil = ouvrirProfilAuteur;
    CommentaireAffiche affiche(Commentaire c) {
      final auteurId = c.auteurId;
      return CommentaireAffiche(
        pseudo: c.auteurPseudo,
        photoUrl: c.auteurPhotoUrl,
        texte: c.texte,
        quand: dateLisibleCommentaire(c.creeLe),
        jaiAime: c.jaiAime,
        libelleJaime: libelleJaimeCommentaire(c.nombreJaime),
        onAimer: () => basculerJaimeCommentaire(c),
        onRepondre: () => repondreA(c),
        onSupprimer: c.estLeMien ? () => supprimerCommentaire(c) : null,
        onTapAuteur: c.estLeMien || auteurId == null || ouvrirProfil == null
            ? null
            : () => ouvrirProfil(auteurId, c.auteurPseudo),
      );
    }

    return [
      for (final fil in filsDeCommentaires(liste))
        FilAffiche(
          commentaire: affiche(fil.commentaire),
          reponses: [for (final r in fil.reponses) affiche(r)],
          reponsesVisibles: filsOuverts.contains(fil.commentaire.id),
          libelleVoirReponses: fil.reponses.isEmpty
              ? null
              : libelleVoirReponses(fil.reponses.length),
          onBasculerReponses: () => setState(() {
            final id = fil.commentaire.id;
            if (!filsOuverts.remove(id)) filsOuverts.add(id);
          }),
        ),
    ];
  }

  /// Le champ, prêt à afficher.
  Widget get champCommentaire => TablSaisieCommentaire(
    controleur: saisieCommentaire,
    focusNode: focusCommentaire,
    onEnvoyer: envoyerCommentaire,
    enCours: envoiCommentaire,
    enReponseA: enReponseA?.auteurPseudo,
    onAnnulerReponse: annulerReponse,
  );
}
