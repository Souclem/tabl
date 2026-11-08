import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Ce qu'on a touché dans la recherche de l'Explorer.
sealed class ChoixRecherche {
  const ChoixRecherche();
}

/// Un endroit (une ville, un quartier, une adresse) : l'Explorer s'y
/// rend.
class EndroitChoisi extends ChoixRecherche {
  const EndroitChoisi(this.zone);

  final ZoneCarte zone;
}

/// « Autour de moi ».
class AutourDeMoiChoisi extends ChoixRecherche {
  const AutourDeMoiChoisi();
}

/// Un restaurant : sa fiche s'ouvre.
class AdresseChoisie extends ChoixRecherche {
  const AdresseChoisie(this.lieu);

  final LieuCarte lieu;
}

/// « Rechercher » : par défaut, on cherche un endroit où explorer — les
/// villes de mon cercle d'abord, puis toute ville, tout quartier, toute
/// adresse. En tête des résultats, de quoi chercher plutôt les
/// restaurants de ce nom. `null` si on annule.
///
/// La pilule de la barre glisse jusqu'en haut pour devenir le champ.
Future<ChoixRecherche?> ouvrirRechercheExplorer(
  BuildContext context, {
  required List<LieuCarte> ici,
  required List<LieuCarte> ailleurs,
  required List<VilleCercle> villes,
  required RechercheEndroitService rechercheEndroit,
  required String Function(int nombre) compte,
  ({double latitude, double longitude})? position,
}) {
  return Navigator.of(context).push<ChoixRecherche>(
    PageRouteBuilder(
      // L'Explorer reste dessiné dessous : la carte doit pouvoir se
      // rendre à l'endroit choisi dès qu'on revient (une carte cachée
      // ignore les déplacements qu'on lui demande).
      opaque: false,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => _RechercheExplorer(
        ici: ici,
        ailleurs: ailleurs,
        villes: villes,
        rechercheEndroit: rechercheEndroit,
        compte: compte,
        position: position,
      ),
      transitionsBuilder: (_, animation, _, enfant) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: enfant,
      ),
    ),
  );
}

class _RechercheExplorer extends StatefulWidget {
  const _RechercheExplorer({
    required this.ici,
    required this.ailleurs,
    required this.villes,
    required this.rechercheEndroit,
    required this.compte,
    required this.position,
  });

  final List<LieuCarte> ici;
  final List<LieuCarte> ailleurs;
  final List<VilleCercle> villes;
  final RechercheEndroitService rechercheEndroit;
  final String Function(int nombre) compte;
  final ({double latitude, double longitude})? position;

  @override
  State<_RechercheExplorer> createState() => _RechercheExplorerState();
}

class _RechercheExplorerState extends State<_RechercheExplorer> {
  final _saisie = TextEditingController();

  /// On cherche des restaurants par leur nom, plutôt qu'un endroit.
  bool _restaurants = false;

  List<EndroitTrouve> _endroits = const [];
  Timer? _attente;
  int _demande = 0;

  /// Au-delà, on demande de préciser.
  static const _maxParSection = 8;

  @override
  void dispose() {
    _attente?.cancel();
    _saisie.dispose();
    super.dispose();
  }

  void _changer(String texte) {
    setState(() {
      if (texte.trim().isEmpty) {
        _restaurants = false;
        _endroits = const [];
      }
    });
    _chercherEndroits();
  }

  /// Une courte pause dans la frappe avant de demander au géocodage.
  void _chercherEndroits() {
    _attente?.cancel();
    final texte = _saisie.text.trim();
    if (texte.isEmpty) return;
    _attente = Timer(const Duration(milliseconds: 300), () async {
      final numero = ++_demande;
      try {
        final endroits = await widget.rechercheEndroit.chercher(
          texte,
          latitude: widget.position?.latitude,
          longitude: widget.position?.longitude,
        );
        if (mounted && numero == _demande) {
          setState(() => _endroits = endroits);
        }
      } catch (e) {
        debugPrint('Recherche : endroits : $e');
      }
    });
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

  void _choisir(ChoixRecherche choix) => Navigator.of(context).pop(choix);

  @override
  Widget build(BuildContext context) {
    final palette = PaletteExplorer.of(context);
    return Scaffold(
      backgroundColor: palette.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 6, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TablChampRechercheExplorer(
                      controleur: _saisie,
                      onChanged: _changer,
                      indication: _restaurants
                          ? 'Le nom d’un restaurant'
                          : 'Une ville, un quartier, une adresse',
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
                children: _restaurants
                    ? _resultatsRestaurants()
                    : _resultatsEndroits(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _resultatsEndroits() {
    final texte = _saisie.text.trim();
    final q = normaliserPourRecherche(texte);
    final villes = [
      for (final v in widget.villes)
        if (q.isEmpty || normaliserPourRecherche(v.nom).contains(q)) v,
    ].take(_maxParSection).toList();
    final dejaLa = {for (final v in villes) normaliserPourRecherche(v.nom)};
    final endroits = [
      for (final e in _endroits)
        if (!dejaLa.contains(normaliserPourRecherche(e.nom))) e,
    ];
    return [
      if (texte.isNotEmpty)
        TablLigneEndroit(
          icone: Icons.restaurant_rounded,
          nom: 'Chercher les restaurants dont le nom est « $texte »',
          enAvant: true,
          onPresse: () => setState(() => _restaurants = true),
        )
      else if (widget.position != null)
        TablLigneEndroit(
          icone: Icons.near_me_rounded,
          nom: 'Autour de moi',
          detail: 'Votre position',
          onPresse: () => _choisir(const AutourDeMoiChoisi()),
        ),
      if (villes.isNotEmpty) ...[
        const TablTitreRecherche('Là où votre cercle a des adresses'),
        for (final v in villes)
          TablLigneEndroit(
            icone: Icons.location_city_rounded,
            nom: v.nom,
            detail: widget.compte(v.compte),
            onPresse: () => _choisir(EndroitChoisi(v.zone)),
          ),
      ],
      if (endroits.isNotEmpty) ...[
        const TablTitreRecherche('Ailleurs'),
        for (final e in endroits)
          TablLigneEndroit(
            icone: Icons.place_outlined,
            nom: e.nom,
            detail: e.detail,
            onPresse: () => _choisir(EndroitChoisi(e.zone)),
          ),
      ],
    ];
  }

  List<Widget> _resultatsRestaurants() {
    final palette = PaletteExplorer.of(context);
    final texte = _saisie.text.trim();
    final q = normaliserPourRecherche(texte);
    final ici = _correspondants(widget.ici, q);
    final ailleurs = _correspondants(widget.ailleurs, q);
    Widget adresse(LieuCarte l) => TablLigneAdresse(
      nom: l.nom,
      resume: resumeRecherche(l),
      genre: _genre(l),
      onPresse: () => _choisir(AdresseChoisie(l)),
    );
    return [
      TablLigneEndroit(
        icone: Icons.place_outlined,
        nom: 'Chercher plutôt un endroit',
        onPresse: () => setState(() => _restaurants = false),
      ),
      if (ici.isEmpty && ailleurs.isEmpty)
        Padding(
          padding: const EdgeInsets.all(TablTokens.espaceXl),
          child: Text(
            'Aucun restaurant de votre cercle ne s’appelle « $texte ».',
            textAlign: TextAlign.center,
            style: TablTokens.corps.copyWith(color: palette.texteDoux),
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
    ];
  }
}
