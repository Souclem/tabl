import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Gérer une Table (megaprompt Bloc 3, règle 56) : renommer, inviter,
/// retirer un membre, quitter, supprimer — tout existait déjà côté
/// `TableService`, rien n'était branché à un écran avant cet ajout.
///
/// Renommer / inviter / retirer / supprimer sont réservés à un admin
/// actif (la RLS le vérifie de toute façon ; ce filtrage côté UI n'est
/// qu'un confort, jamais la seule barrière) — "Quitter" reste ouvert à
/// tout membre, y compris un admin.
class EcranGererTable extends StatefulWidget {
  const EcranGererTable({
    super.key,
    required this.table,
    required this.tableService,
    required this.abonnementService,
  });

  final GroupeTable table;
  final TableService tableService;
  final AbonnementService abonnementService;

  @override
  State<EcranGererTable> createState() => _EcranGererTableState();
}

class _EcranGererTableState extends State<EcranGererTable> {
  late GroupeTable _table = widget.table;
  late final _nom = TextEditingController(text: _table.nom);
  bool _renommageEnCours = false;

  Future<void> _rafraichir() async {
    final table = await widget.tableService.table(widget.table.id);
    if (!mounted) return;
    setState(() => _table = table);
  }

  Future<void> _renommer() async {
    final nom = _nom.text.trim();
    if (nom.isEmpty || nom == _table.nom) return;
    setState(() => _renommageEnCours = true);
    try {
      await widget.tableService.renommer(_table.id, nom);
      await _rafraichir();
    } catch (_) {
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => _renommageEnCours = false);
    }
  }

  Future<void> _inviter() async {
    final amis = await widget.abonnementService.mesAmis();
    if (!mounted) return;
    final dejaMembres = _table.membres.map((m) => m.profilId).toSet();
    final candidats = amis.where((a) => !dejaMembres.contains(a.id)).toList();
    final choisi = await showModalBottomSheet<ProfilPublic>(
      context: context,
      backgroundColor: TablTokens.surface,
      builder: (_) => _SheetChoixAmi(candidats: candidats),
    );
    if (choisi == null || !mounted) return;
    try {
      await widget.tableService.inviter(_table.id, choisi.id);
      await _rafraichir();
    } catch (_) {
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    }
  }

  Future<void> _retirer(MembreTable membre) async {
    final confirme = await _confirmer(
      titre: 'Retirer ${membre.pseudo} ?',
      message: '${membre.pseudo} n\'aura plus accès à cette Table.',
      libelleAction: 'Retirer',
    );
    if (!confirme || !mounted) return;
    try {
      await widget.tableService.retirerMembre(_table.id, membre.profilId);
      await _rafraichir();
    } catch (_) {
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    }
  }

  Future<void> _quitter() async {
    final confirme = await _confirmer(
      titre: 'Quitter ${_table.nom} ?',
      message:
          'Vous n\'aurez plus accès à cette Table. Vos souvenirs déjà '
          'partagés y restent.',
      libelleAction: 'Quitter',
    );
    if (!confirme || !mounted) return;
    try {
      await widget.tableService.quitter(_table.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    }
  }

  Future<void> _supprimer() async {
    final confirme = await _confirmer(
      titre: 'Supprimer ${_table.nom} ?',
      message:
          'La Table disparaît pour tous ses membres. Les souvenirs qui y '
          'étaient partagés ne sont pas supprimés.',
      libelleAction: 'Supprimer',
    );
    if (!confirme || !mounted) return;
    try {
      await widget.tableService.supprimer(_table.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    }
  }

  Future<bool> _confirmer({
    required String titre,
    required String message,
    required String libelleAction,
  }) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TablTokens.surface,
        title: Text(titre, style: TablTokens.sousTitre),
        content: Text(message, style: TablTokens.corps),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              libelleAction,
              style: const TextStyle(color: TablTokens.erreur),
            ),
          ),
        ],
      ),
    );
    return confirme ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final estAdmin = _table.jeSuisAdmin;
    return Scaffold(
      backgroundColor: TablTokens.fond,
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
                  TablBoutonRetour(onPresse: () => Navigator.of(context).pop(false)),
                  const SizedBox(width: TablTokens.espaceM),
                  Text('Gérer la Table', style: TablTokens.titre),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(TablTokens.espaceL),
                children: [
                  TablChampTexte(
                    libelle: 'Nom',
                    controleur: _nom,
                    indication: _table.nom,
                    actif: estAdmin,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (estAdmin) ...[
                    const SizedBox(height: TablTokens.espaceS),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TablBouton(
                        libelle: 'Renommer',
                        enCours: _renommageEnCours,
                        onPresse:
                            _nom.text.trim().isNotEmpty && _nom.text.trim() != _table.nom
                                ? _renommer
                                : null,
                      ),
                    ),
                  ],
                  const SizedBox(height: TablTokens.espaceL),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Membres', style: TablTokens.sousTitre),
                      if (estAdmin)
                        TextButton(onPressed: _inviter, child: const Text('Inviter')),
                    ],
                  ),
                  const SizedBox(height: TablTokens.espaceXs),
                  for (final membre in _table.membres)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(membre.pseudo, style: TablTokens.corps),
                      subtitle: Text(
                        _libelleStatut(membre),
                        style: TablTokens.legende.copyWith(color: TablTokens.texteDoux),
                      ),
                      trailing: estAdmin && !membre.estAdmin
                          ? IconButton(
                              icon: const Icon(Icons.close, color: TablTokens.texteDoux),
                              tooltip: 'Retirer',
                              onPressed: () => _retirer(membre),
                            )
                          : null,
                    ),
                  const SizedBox(height: TablTokens.espaceXl),
                  OutlinedButton(onPressed: _quitter, child: const Text('Quitter la Table')),
                  if (estAdmin) ...[
                    const SizedBox(height: TablTokens.espaceS),
                    OutlinedButton(
                      onPressed: _supprimer,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TablTokens.erreur,
                        side: const BorderSide(color: TablTokens.erreur),
                      ),
                      child: const Text('Supprimer la Table'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _libelleStatut(MembreTable membre) {
    final role = membre.estAdmin ? 'Admin' : 'Membre';
    return switch (membre.statut.valeur) {
      'en_attente' => 'En attente',
      'parti' => 'A quitté',
      'retire' => 'Retiré',
      _ => role,
    };
  }
}

class _SheetChoixAmi extends StatelessWidget {
  const _SheetChoixAmi({required this.candidats});

  final List<ProfilPublic> candidats;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(TablTokens.espaceL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Inviter', style: TablTokens.sousTitre),
            const SizedBox(height: TablTokens.espaceS),
            if (candidats.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceM),
                child: Text(
                  'Tout votre cercle est déjà dans cette Table.',
                  style: TablTokens.legende.copyWith(color: TablTokens.texteDoux),
                ),
              )
            else
              for (final ami in candidats)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ami.pseudo, style: TablTokens.corps),
                  onTap: () => Navigator.of(context).pop(ami),
                ),
          ],
        ),
      ),
    );
  }
}
