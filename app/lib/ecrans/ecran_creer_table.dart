import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Créer une Table (megaprompt Bloc 3, règle 50) : nom, emoji optionnel,
/// membres, créer — rien d'autre. Minimiser la friction : pas de
/// catégorie, pas de thème, pas de bio obligatoire.
class EcranCreerTable extends StatefulWidget {
  const EcranCreerTable({
    super.key,
    required this.tableService,
    required this.abonnementService,
  });

  final TableService tableService;
  final AbonnementService abonnementService;

  @override
  State<EcranCreerTable> createState() => _EcranCreerTableState();
}

class _EcranCreerTableState extends State<EcranCreerTable> {
  final _nom = TextEditingController();
  final _emoji = TextEditingController();
  final Set<String> _membresSelectionnes = {};

  bool _enCours = false;
  List<ProfilPublic> _amis = [];
  bool _chargementAmis = true;

  @override
  void initState() {
    super.initState();
    _chargerAmis();
  }

  @override
  void dispose() {
    _nom.dispose();
    _emoji.dispose();
    super.dispose();
  }

  Future<void> _chargerAmis() async {
    try {
      final amis = await widget.abonnementService.mesAmis();
      if (!mounted) return;
      setState(() {
        _amis = amis;
        _chargementAmis = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _chargementAmis = false);
    }
  }

  bool get _peutCreer => _nom.text.trim().isNotEmpty && !_enCours;

  Future<void> _creer() async {
    setState(() => _enCours = true);
    try {
      await widget.tableService.creer(
        nom: _nom.text.trim(),
        emoji: _emoji.text.trim().isEmpty ? null : _emoji.text.trim(),
        membresInvitesIds: _membresSelectionnes.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
      setState(() => _enCours = false);
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
                TablTokens.espaceL,
                TablTokens.espaceM,
                TablTokens.espaceL,
                0,
              ),
              child: Row(
                children: [
                  TablBoutonRetour(onPresse: () => Navigator.of(context).pop(false)),
                  const SizedBox(width: TablTokens.espaceM),
                  Text('Nouvelle Table', style: TablTokens.titre),
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
                    indication: 'Marbella, Les gars, Famille…',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: TablTokens.espaceM),
                  TablChampTexte(
                    libelle: 'Emoji (optionnel)',
                    controleur: _emoji,
                    indication: '☀️',
                  ),
                  const SizedBox(height: TablTokens.espaceL),
                  Text('Membres', style: TablTokens.sousTitre),
                  const SizedBox(height: TablTokens.espaceS),
                  if (_chargementAmis)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: TablTokens.espaceM),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: TablTokens.primaire,
                          ),
                        ),
                      ),
                    )
                  else if (_amis.isEmpty)
                    Text(
                      'Votre cercle est vide pour le moment.',
                      style: TablTokens.legende.copyWith(color: TablTokens.texteDoux),
                    )
                  else
                    for (final ami in _amis)
                      CheckboxListTile(
                        value: _membresSelectionnes.contains(ami.id),
                        onChanged: (coche) => setState(() {
                          if (coche ?? false) {
                            _membresSelectionnes.add(ami.id);
                          } else {
                            _membresSelectionnes.remove(ami.id);
                          }
                        }),
                        title: Text(ami.pseudo, style: TablTokens.corps),
                        activeColor: TablTokens.primaire,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(TablTokens.espaceL),
              child: TablBouton(
                libelle: 'Créer',
                enCours: _enCours,
                onPresse: _peutCreer ? _creer : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
