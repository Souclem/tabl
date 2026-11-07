import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_creer_table.dart';
import 'ecran_table.dart';

/// "Vos Tables" (megaprompt Bloc 3, règles 5-9) : liste compacte,
/// premium, humaine — jamais de giant hero cards, jamais de dashboard.
/// Onglet de la barre de navigation (à gauche du ➕) depuis le
/// 2026-10-16, à la place de l'ancien Explorer — le megaprompt
/// l'interdisait, décision produit revue depuis.
class EcranTables extends StatefulWidget {
  const EcranTables({
    super.key,
    required this.tableService,
    required this.abonnementService,
    this.souvenirService,
    this.estOnglet = false,
  });

  final TableService tableService;
  final AbonnementService abonnementService;

  /// Transmis jusqu'à la carte d'une Table (page des restaurants).
  final SouvenirService? souvenirService;

  /// Affiché comme onglet : pas de bouton retour, et une marge basse
  /// pour la barre de navigation flottante.
  final bool estOnglet;

  @override
  State<EcranTables> createState() => _EcranTablesState();
}

class _EcranTablesState extends State<EcranTables> {
  bool _chargement = true;
  bool _erreur = false;
  List<ResumeTable> _tables = const [];
  List<ResumeTable> _invitations = const [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = false;
    });
    try {
      final resultats = await Future.wait([
        widget.tableService.mesTables(),
        widget.tableService.mesInvitations(),
      ]);
      if (!mounted) return;
      setState(() {
        _tables = resultats[0];
        _invitations = resultats[1];
        _chargement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = true;
      });
    }
  }

  Future<void> _accepter(String tableId) async {
    await widget.tableService.accepterInvitation(tableId);
    await _charger();
  }

  Future<void> _refuser(String tableId) async {
    await widget.tableService.refuserInvitation(tableId);
    await _charger();
  }

  Future<void> _ouvrirTable(String tableId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranTable(
          tableId: tableId,
          tableService: widget.tableService,
          abonnementService: widget.abonnementService,
          souvenirService: widget.souvenirService,
        ),
      ),
    );
    if (mounted) _charger();
  }

  Future<void> _creerTable() async {
    final creee = await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => EcranCreerTable(
          tableService: widget.tableService,
          abonnementService: widget.abonnementService,
        ),
      ),
    );
    if (creee == true && mounted) _charger();
  }

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Scaffold(
      backgroundColor: c.fond,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TablTokens.espaceL,
                TablTokens.espaceM,
                TablTokens.espaceL,
                0,
              ),
              child: Row(
                children: [
                  if (!widget.estOnglet) ...[
                    TablBoutonRetour(
                      onPresse: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: TablTokens.espaceM),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vos Tables', style: c.titre),
                        Text(
                          'Vos restaurants, entre vous.',
                          style: c.legende.copyWith(color: c.texteDoux),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: c.primaire),
                    onPressed: _creerTable,
                  ),
                ],
              ),
            ),
            Expanded(child: _corps()),
          ],
        ),
      ),
    );
  }

  Widget _corps() {
    final c = TablCouleurs.of(context);
    if (_chargement) {
      return Center(child: CircularProgressIndicator(color: c.primaire));
    }
    if (_erreur) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Impossible de charger vos Tables.', style: c.corps),
            const SizedBox(height: TablTokens.espaceM),
            OutlinedButton(onPressed: _charger, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_tables.isEmpty && _invitations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(TablTokens.espaceL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Créez votre première Table pour garder une trace de vos '
                'restaurants avec vos proches.',
                style: c.corps,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: TablTokens.espaceM),
              TablBouton(libelle: 'Créer une Table', onPresse: _creerTable),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(
        TablTokens.espaceL,
        0,
        TablTokens.espaceL,
        // Comme onglet, la barre de navigation flotte par-dessus.
        widget.estOnglet ? TablTokens.espaceXxl + TablTokens.espaceL : 0,
      ),
      children: [
        if (_invitations.isNotEmpty) ...[
          const SizedBox(height: TablTokens.espaceM),
          Text('Invitations', style: c.sousTitre),
          for (final invitation in _invitations)
            _LigneInvitation(
              invitation: invitation,
              onAccepter: () => _accepter(invitation.id),
              onRefuser: () => _refuser(invitation.id),
            ),
          const SizedBox(height: TablTokens.espaceL),
        ],
        for (final table in _tables)
          TablLigneTable(
            nom: table.nom,
            emoji: table.emoji,
            visuelUrls: table.couverturePhotoUrl != null
                ? [table.couverturePhotoUrl!]
                : table.mosaiquePhotosUrls,
            nombreMembres: table.nombreMembres,
            etatTexte: table.etatTexte,
            actionRequise: table.actionRequise,
            onTap: () => _ouvrirTable(table.id),
          ),
        const SizedBox(height: TablTokens.espaceL),
      ],
    );
  }
}

class _LigneInvitation extends StatelessWidget {
  const _LigneInvitation({
    required this.invitation,
    required this.onAccepter,
    required this.onRefuser,
  });

  final ResumeTable invitation;
  final VoidCallback onAccepter;
  final VoidCallback onRefuser;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceS),
      child: Row(
        children: [
          Expanded(
            child: Text(
              invitation.emoji == null
                  ? invitation.nom
                  : '${invitation.nom} ${invitation.emoji}',
              style: c.corps,
            ),
          ),
          TextButton(onPressed: onRefuser, child: const Text('Refuser')),
          const SizedBox(width: TablTokens.espaceXs),
          FilledButton(
            onPressed: onAccepter,
            style: FilledButton.styleFrom(
              backgroundColor: c.primaire,
              foregroundColor: c.texteSurPrimaire,
            ),
            child: const Text('Accepter'),
          ),
        ],
      ),
    );
  }
}
