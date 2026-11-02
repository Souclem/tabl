import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Ce qu'on a touché dans la recherche de l'Explorer.
sealed class ChoixRecherche {
  const ChoixRecherche();
}

/// Une adresse : sa fiche s'ouvre.
class AdresseChoisie extends ChoixRecherche {
  const AdresseChoisie(this.lieu);

  final LieuCarte lieu;
}

/// Un proche : la grille ne montre plus que ses adresses.
class ProcheChoisi extends ChoixRecherche {
  const ProcheChoisi(this.proche);

  final ProfilPublic proche;
}

/// « Rechercher » (maquette de Martin) : les restaurants du cercle dans
/// la zone regardée, puis ceux d'ailleurs, puis les proches dont le
/// prénom correspond. `null` si on annule.
Future<ChoixRecherche?> ouvrirRechercheExplorer(
  BuildContext context, {
  required List<LieuCarte> ici,
  required List<LieuCarte> ailleurs,
  required List<ProfilPublic> proches,
}) {
  return Navigator.of(context).push<ChoixRecherche>(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) =>
          _RechercheExplorer(ici: ici, ailleurs: ailleurs, proches: proches),
      transitionsBuilder: (_, animation, _, enfant) =>
          FadeTransition(opacity: animation, child: enfant),
    ),
  );
}

class _RechercheExplorer extends StatefulWidget {
  const _RechercheExplorer({
    required this.ici,
    required this.ailleurs,
    required this.proches,
  });

  final List<LieuCarte> ici;
  final List<LieuCarte> ailleurs;
  final List<ProfilPublic> proches;

  @override
  State<_RechercheExplorer> createState() => _RechercheExplorerState();
}

class _RechercheExplorerState extends State<_RechercheExplorer> {
  final _saisie = TextEditingController();

  /// Au-delà, on demande de préciser.
  static const _maxParSection = 8;

  @override
  void dispose() {
    _saisie.dispose();
    super.dispose();
  }

  List<LieuCarte> _correspondants(List<LieuCarte> lieux, String q) => [
    for (final l in lieux)
      if (normaliserPourRecherche(l.nom).contains(q)) l,
  ].take(_maxParSection).toList();

  GenreTuile _genre(LieuCarte l) => switch (teinteLieu(l)) {
    TeinteLieu.cercle => GenreTuile.cercle,
    TeinteLieu.retour => GenreTuile.retour,
    TeinteLieu.vous => GenreTuile.vous,
  };

  @override
  Widget build(BuildContext context) {
    final palette = PaletteExplorer.of(context);
    final q = normaliserPourRecherche(_saisie.text);
    final ici = q.isEmpty
        ? const <LieuCarte>[]
        : _correspondants(widget.ici, q);
    final ailleurs = q.isEmpty
        ? const <LieuCarte>[]
        : _correspondants(widget.ailleurs, q);
    final proches = q.isEmpty
        ? const <ProfilPublic>[]
        : prochesCorrespondants(widget.proches, q).proches;
    Widget adresse(LieuCarte l) => TablLigneAdresse(
      nom: l.nom,
      resume: resumeRecherche(l),
      genre: _genre(l),
      onPresse: () => Navigator.of(context).pop(AdresseChoisie(l)),
    );
    return Scaffold(
      backgroundColor: palette.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: palette == PaletteExplorer.clair
                            ? Colors.white
                            : palette.barre,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: palette.trait),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 21,
                            color: palette.texte,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _saisie,
                              autofocus: true,
                              autocorrect: false,
                              onChanged: (_) => setState(() {}),
                              cursorColor: palette.texte,
                              style: TablTokens.corps.copyWith(
                                fontSize: 16,
                                color: palette.texte,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintText: 'Un restaurant, un proche',
                                hintStyle: TablTokens.corps.copyWith(
                                  fontSize: 16,
                                  color: palette.texteDoux,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Annuler',
                      style: TablTokens.corps.copyWith(
                        fontWeight: FontWeight.w600,
                        color: palette.texte,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: TablTokens.espaceXl),
                children: [
                  if (q.isNotEmpty &&
                      ici.isEmpty &&
                      ailleurs.isEmpty &&
                      proches.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(TablTokens.espaceXl),
                      child: Text(
                        'Rien ne correspond à « ${_saisie.text.trim()} ».',
                        textAlign: TextAlign.center,
                        style: TablTokens.corps.copyWith(
                          color: palette.texteDoux,
                        ),
                      ),
                    ),
                  if (ici.isNotEmpty) ...[
                    const TablTitreRecherche('Restaurants de votre cercle'),
                    for (final l in ici) adresse(l),
                  ],
                  if (ailleurs.isNotEmpty) ...[
                    const TablTitreRecherche('Ailleurs'),
                    for (final l in ailleurs) adresse(l),
                  ],
                  if (proches.isNotEmpty) ...[
                    const TablTitreRecherche('Vos proches'),
                    for (final p in proches)
                      TablLigneProcheRecherche(
                        pseudo: p.pseudo,
                        photoUrl: p.photoUrl,
                        onPresse: () =>
                            Navigator.of(context).pop(ProcheChoisi(p)),
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
}
