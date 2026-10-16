import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Le mini-chat "Organisation" d'une proposition (megaprompt Bloc 4,
/// règles 38-48) : texte seul, jamais de pièce jointe, pas de statut
/// "vu". L'accès (creator ou GO actif) est vérifié côté base (RLS) —
/// cet écran n'a pas à le revérifier lui-même.
class EcranOrganisationTable extends StatefulWidget {
  const EcranOrganisationTable({
    super.key,
    required this.propositionId,
    required this.tableService,
  });

  final String propositionId;
  final TableService tableService;

  @override
  State<EcranOrganisationTable> createState() => _EcranOrganisationTableState();
}

class _EcranOrganisationTableState extends State<EcranOrganisationTable> {
  bool _chargement = true;
  List<MessageOrganisation> _messages = const [];
  final _controleur = TextEditingController();
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    final messages = await widget.tableService.messagesOrganisation(widget.propositionId);
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _chargement = false;
    });
  }

  Future<void> _envoyer() async {
    final texte = _controleur.text.trim();
    if (texte.isEmpty || _envoi) return;
    setState(() => _envoi = true);
    await widget.tableService.envoyerMessageOrganisation(widget.propositionId, texte);
    _controleur.clear();
    await _charger();
    if (!mounted) return;
    setState(() => _envoi = false);
  }

  Future<void> _supprimer(String messageId) async {
    await widget.tableService.supprimerMessageOrganisation(messageId);
    await _charger();
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
              padding: const EdgeInsets.symmetric(
                horizontal: TablTokens.espaceM,
                vertical: TablTokens.espaceS,
              ),
              child: Row(
                children: [
                  TablBoutonRetour(onPresse: () => Navigator.of(context).pop()),
                  const SizedBox(width: TablTokens.espaceS),
                  const Text('Organisation', style: TablTokens.sousTitre),
                ],
              ),
            ),
            const Divider(color: TablTokens.bordure, height: 1),
            Expanded(
              child: _chargement
                  ? const Center(
                      child: CircularProgressIndicator(color: TablTokens.primaire),
                    )
                  : _messages.isEmpty
                  ? const Center(
                      child: Text(
                        'Discutez des détails pratiques ici.',
                        style: TablTokens.corps,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: TablTokens.espaceM,
                        vertical: TablTokens.espaceS,
                      ),
                      children: [
                        for (final m in _messages)
                          TablBulleMessageOrganisation(
                            auteurPseudo: m.auteurPseudo,
                            contenu: m.contenu,
                            parMoi: m.parMoi,
                            onSupprimer: m.parMoi ? () => _supprimer(m.id) : null,
                          ),
                      ],
                    ),
            ),
            const Divider(color: TablTokens.bordure, height: 1),
            Padding(
              padding: const EdgeInsets.all(TablTokens.espaceS),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controleur,
                      style: TablTokens.corps,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        hintText: 'Message...',
                        border: InputBorder.none,
                        counterText: '',
                      ),
                      onSubmitted: (_) => _envoyer(),
                    ),
                  ),
                  IconButton(
                    onPressed: _envoi ? null : _envoyer,
                    icon: const Icon(Icons.send, color: TablTokens.primaire),
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
