import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Les commentaires d'un souvenir : liste + ajout. Pas d'édition — on
/// commente, on peut retirer son propre commentaire, on ne le corrige
/// pas après coup.
class EcranCommentaires extends StatefulWidget {
  const EcranCommentaires({
    super.key,
    required this.souvenirService,
    required this.souvenirId,
  });

  final SouvenirService souvenirService;
  final String souvenirId;

  @override
  State<EcranCommentaires> createState() => _EcranCommentairesState();
}

class _EcranCommentairesState extends State<EcranCommentaires> {
  final _texte = TextEditingController();

  List<Commentaire>? _commentaires;
  bool _envoiEnCours = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final commentaires = await widget.souvenirService.commentaires(
        widget.souvenirId,
      );
      if (!mounted) return;
      setState(() => _commentaires = commentaires);
    } catch (_) {
      if (!mounted) return;
      // Sans ça, `_commentaires` reste `null` pour toujours : l'écran
      // resterait bloqué sur le spinner de chargement au lieu de
      // signaler l'échec.
      setState(() => _commentaires = []);
      afficherMessage(context, messageErreurGenerique);
    }
  }

  Future<void> _envoyer() async {
    final texte = _texte.text.trim();
    if (texte.isEmpty) return;

    setState(() => _envoiEnCours = true);
    try {
      await widget.souvenirService.commenter(widget.souvenirId, texte);
      _texte.clear();
      await _charger();
    } catch (_) {
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  Future<void> _supprimer(Commentaire commentaire) async {
    try {
      await widget.souvenirService.supprimerCommentaire(commentaire.id);
      await _charger();
    } catch (_) {
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablTokens.fond,
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
              child: Row(
                children: [
                  TablBoutonRetour(
                    onPresse: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: TablTokens.espaceM),
                  Text('Commentaires', style: TablTokens.titre),
                ],
              ),
            ),
            Expanded(child: _corps()),
            _champSaisie(),
          ],
        ),
      ),
    );
  }

  Widget _corps() {
    final commentaires = _commentaires;
    if (commentaires == null) {
      return const Center(
        child: CircularProgressIndicator(color: TablTokens.primaire),
      );
    }
    if (commentaires.isEmpty) {
      return Center(
        child: Text(
          'Aucun commentaire pour l\'instant.',
          style: TablTokens.corps.copyWith(color: TablTokens.texteDoux),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(TablTokens.espaceL),
      itemCount: commentaires.length,
      itemBuilder: (context, index) {
        final commentaire = commentaires[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: TablTokens.espaceM),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(commentaire.auteurPseudo, style: TablTokens.sousTitre),
                    const SizedBox(height: TablTokens.espaceXs),
                    Text(commentaire.texte, style: TablTokens.corps),
                  ],
                ),
              ),
              if (commentaire.estLeMien)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: TablTokens.texteDoux,
                    size: 20,
                  ),
                  onPressed: () => _supprimer(commentaire),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _champSaisie() {
    return Padding(
      padding: const EdgeInsets.all(TablTokens.espaceM),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _texte,
              enabled: !_envoiEnCours,
              style: TablTokens.corps,
              onSubmitted: (_) => _envoyer(),
              decoration: InputDecoration(
                hintText: 'Ajouter un commentaire…',
                hintStyle: TablTokens.corps.copyWith(
                  color: TablTokens.texteDoux,
                ),
                filled: true,
                fillColor: TablTokens.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: TablTokens.espaceM,
                  vertical: TablTokens.espaceM,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TablTokens.arrondiS),
                  borderSide: const BorderSide(color: TablTokens.bordure),
                ),
              ),
            ),
          ),
          const SizedBox(width: TablTokens.espaceS),
          IconButton(
            onPressed: _envoiEnCours ? null : _envoyer,
            icon: const Icon(Icons.send_rounded, color: TablTokens.primaire),
          ),
        ],
      ),
    );
  }
}
