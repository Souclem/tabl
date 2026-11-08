import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Tous les filtres de l'Explorer dans une feuille claire, une ligne par
/// filtre (« A · Carnet », maquette de Martin) : une seule ligne ouverte
/// à la fois, rien ne s'applique avant « Voir 12 adresses », et
/// [compter] dit en direct combien d'adresses resteraient. Renvoie les
/// filtres choisis, `null` si la feuille est fermée sans valider.
Future<FiltresCarte?> ouvrirFiltresExplorer(
  BuildContext context, {
  required FiltresCarte filtres,
  required List<ProfilPublic> personnes,
  required List<ResumeTable> tables,
  required Future<int> Function(FiltresCarte filtres) compter,
}) {
  return showModalBottomSheet<FiltresCarte>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TablCouleurs.of(context).surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _FeuilleFiltres(
      filtres: filtres,
      personnes: personnes,
      tables: tables,
      compter: compter,
    ),
  );
}

/// Les lignes qui se déplient.
enum _Ligne { moment, periode, cuisine, proche, table, histoire }

class _FeuilleFiltres extends StatefulWidget {
  const _FeuilleFiltres({
    required this.filtres,
    required this.personnes,
    required this.tables,
    required this.compter,
  });

  final FiltresCarte filtres;
  final List<ProfilPublic> personnes;
  final List<ResumeTable> tables;
  final Future<int> Function(FiltresCarte filtres) compter;

  @override
  State<_FeuilleFiltres> createState() => _FeuilleFiltresState();
}

class _FeuilleFiltresState extends State<_FeuilleFiltres> {
  late FiltresCarte _f = widget.filtres;
  _Ligne? _ouverte;
  final _recherche = TextEditingController();

  /// Les adresses qui resteraient avec ces filtres ; `null` tant qu'on
  /// ne le sait pas.
  int? _compte;
  Timer? _attente;
  int _demande = 0;

  static const _moments = ['midi', 'soir'];

  @override
  void initState() {
    super.initState();
    _compter(toutDeSuite: true);
  }

  @override
  void dispose() {
    _attente?.cancel();
    _recherche.dispose();
    super.dispose();
  }

  void _changer(FiltresCarte f) {
    setState(() => _f = f);
    _compter();
  }

  /// Une courte pause après chaque choix : plusieurs touchers à la suite
  /// ne demandent qu'un compte.
  void _compter({bool toutDeSuite = false}) {
    _attente?.cancel();
    _attente = Timer(
      toutDeSuite ? Duration.zero : const Duration(milliseconds: 250),
      () async {
        final numero = ++_demande;
        try {
          final compte = await widget.compter(_f);
          if (mounted && numero == _demande) setState(() => _compte = compte);
        } catch (e) {
          debugPrint('Filtres : compte : $e');
        }
      },
    );
  }

  void _ouvrir(_Ligne ligne) => setState(() {
    _ouverte = _ouverte == ligne ? null : ligne;
    _recherche.clear();
  });

  TablLigneCarnet _ligne(
    _Ligne ligne,
    String libelle,
    String valeur, {
    required bool actif,
    required Widget Function() contenu,
  }) => TablLigneCarnet(
    libelle: libelle,
    valeur: valeur,
    actif: actif,
    ouverte: _ouverte == ligne,
    onPresse: () => _ouvrir(ligne),
    contenu: _ouverte == ligne ? contenu() : const SizedBox.shrink(),
  );

  @override
  Widget build(BuildContext context) {
    final f = _f;
    final familles = famillesCuisine.keys.toList();
    final pseudo = widget.personnes
        .where((p) => p.id == f.personneId)
        .firstOrNull
        ?.pseudo;
    final indexTable = widget.tables.indexWhere((t) => t.id == f.tableId);
    final compte = _compte;
    return Padding(
      // Le champ « Chercher un proche » reste au-dessus du clavier.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SafeArea(
          top: false,
          child: TablFeuilleCarnet(
            compte: compte == null ? null : nombreAdresses(compte),
            libelleVoir: compte == null
                ? 'Voir les adresses'
                : compte == 0
                ? 'Aucune adresse'
                : 'Voir ${nombreAdresses(compte)}',
            onVoir: () => Navigator.of(context).pop(_f),
            onFermer: () => Navigator.of(context).pop(),
            onToutEffacer: f.nombreActifs == 0
                ? null
                : () => _changer(FiltresCarte.aucun),
            lignes: [
              _ligne(
                _Ligne.moment,
                'Moment',
                valeurMoment(f.moment),
                actif: f.moment != null,
                contenu: () => TablTuilesCarnet(
                  options: [
                    for (final m in _moments)
                      (
                        libelle: valeurMoment(m),
                        icone: m == 'midi'
                            ? Icons.wb_sunny_outlined
                            : Icons.nightlight_outlined,
                      ),
                  ],
                  choisies: {
                    for (var i = 0; i < _moments.length; i++)
                      if (f.moment == _moments[i]) i,
                  },
                  onBasculer: (i) => _changer(
                    f.copierAvec(
                      moment: () =>
                          f.moment == _moments[i] ? null : _moments[i],
                    ),
                  ),
                ),
              ),
              _ligne(
                _Ligne.periode,
                'Période',
                valeurPeriode(f.periode),
                actif: f.periode != PeriodeCarte.tout,
                contenu: () => TablSegmentsCarnet(
                  options: [for (final p in PeriodeCarte.values) p.libelle],
                  choisi: f.periode.index,
                  onChoisir: (i) =>
                      _changer(f.copierAvec(periode: PeriodeCarte.values[i])),
                ),
              ),
              _ligne(
                _Ligne.cuisine,
                'Cuisine',
                valeurCuisine(f.familles),
                actif: f.familles.isNotEmpty,
                contenu: () => TablPastillesCarnet(
                  options: familles,
                  choisies: {
                    for (var i = 0; i < familles.length; i++)
                      if (f.familles.contains(familles[i])) i,
                  },
                  onBasculer: (i) => _changer(
                    f.copierAvec(
                      familles: f.familles.contains(familles[i])
                          ? ({...f.familles}..remove(familles[i]))
                          : {...f.familles, familles[i]},
                    ),
                  ),
                ),
              ),
              if (widget.personnes.isNotEmpty)
                _ligne(
                  _Ligne.proche,
                  'Un proche',
                  valeurProche(pseudo),
                  actif: f.personneId != null,
                  contenu: () => _rechercheProche(f),
                ),
              if (widget.tables.isNotEmpty)
                _ligne(
                  _Ligne.table,
                  'Une Table',
                  valeurTable(
                    indexTable < 0 ? null : widget.tables[indexTable].nom,
                  ),
                  actif: f.tableId != null,
                  contenu: () => TablPastillesCarnet(
                    options: [for (final t in widget.tables) t.nom],
                    choisies: {if (indexTable >= 0) indexTable},
                    onBasculer: (i) => _changer(
                      f.copierAvec(
                        tableId: () =>
                            i == indexTable ? null : widget.tables[i].id,
                      ),
                    ),
                  ),
                ),
              _ligne(
                _Ligne.histoire,
                'Mon histoire',
                valeurHistoire(f.jamaisEssaye),
                actif: f.jamaisEssaye,
                contenu: () => TablSegmentsCarnet(
                  options: const ['Toutes', 'Pas encore essayées'],
                  choisi: f.jamaisEssaye ? 1 : 0,
                  onChoisir: (i) =>
                      _changer(f.copierAvec(jamaisEssaye: i == 1)),
                ),
              ),
              TablInterrupteurCarnet(
                libelle: 'Coups de cœur',
                actif: f.coupsDeCoeur,
                onChanger: () =>
                    _changer(f.copierAvec(coupsDeCoeur: !f.coupsDeCoeur)),
              ),
              TablInterrupteurCarnet(
                libelle: 'Là où on revient',
                actif: f.laOuOnRevient,
                onChanger: () =>
                    _changer(f.copierAvec(laOuOnRevient: !f.laOuOnRevient)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// « Un proche » : sans rien taper, les premiers proches (celui qu'on a
  /// choisi d'abord) ; en tapant, ceux dont le prénom commence par la
  /// saisie d'abord.
  Widget _rechercheProche(FiltresCarte f) {
    final requete = _recherche.text.trim();
    final trouves = prochesCorrespondants(widget.personnes, requete);
    var proches = trouves.proches;
    final choisi = widget.personnes
        .where((p) => p.id == f.personneId)
        .firstOrNull;
    if (requete.isEmpty && choisi != null && !proches.contains(choisi)) {
      proches = [choisi, ...proches.take(proches.length - 1)];
    }
    final autres = trouves.autres;
    return TablRechercheProche(
      controleur: _recherche,
      onChanged: (_) => setState(() {}),
      aide: proches.isEmpty
          ? 'Aucun proche ne s’appelle « $requete ».'
          : autres == 0
          ? null
          : requete.isEmpty
          ? 'Et $autres autres · tapez un prénom'
          : 'Et $autres autres · précisez',
      proches: [
        for (final p in proches)
          ProcheAffiche(
            pseudo: p.pseudo,
            photoUrl: p.photoUrl,
            lettresSoulignees: debutCorrespondant(p.pseudo, requete),
            choisi: p.id == f.personneId,
            onPresse: () {
              _recherche.clear();
              _changer(
                f.copierAvec(
                  personneId: () => p.id == f.personneId ? null : p.id,
                ),
              );
            },
          ),
      ],
    );
  }
}

/// « Où cherchez-vous ? » : autour de moi, ou l'une des villes où mon
/// cercle a des adresses, avec leur nombre. Renvoie la ville choisie,
/// [autourDeMoi] pour « Autour de moi », `null` si la feuille est fermée.
Future<Object?> ouvrirOuChercher(
  BuildContext context, {
  required List<VilleCercle> villes,
  required String? villeActuelle,
  required bool positionConnue,
  required String Function(int nombre) compte,
}) {
  return showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    backgroundColor: TablCouleurs.of(context).surfaceBasse,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (contexte) {
      final c = TablCouleurs.of(contexte);
      Widget ligne({
        required IconData icone,
        required String titre,
        required String sousTitre,
        required bool actuelle,
        required Object valeur,
      }) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: actuelle
                ? c.primaire.withValues(alpha: 0.1)
                : c.texte.withValues(alpha: 0.035),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(TablTokens.arrondiM),
              side: BorderSide(
                color: actuelle
                    ? c.primaire.withValues(alpha: 0.5)
                    : c.texte.withValues(alpha: 0.07),
              ),
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TablTokens.arrondiM),
              ),
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.texte.withValues(alpha: 0.06),
                ),
                child: Icon(icone, size: 17, color: c.texte),
              ),
              title: Text(
                titre,
                style: c.corps.copyWith(
                  fontWeight: FontWeight.w600,
                  color: actuelle ? c.primaire : c.texte,
                ),
              ),
              subtitle: Text(
                sousTitre,
                style: c.legende.copyWith(fontSize: 12.5),
              ),
              trailing: actuelle
                  ? Icon(Icons.check_rounded, color: c.primaire)
                  : null,
              onTap: () => Navigator.of(contexte).pop(valeur),
            ),
          ),
        );
      }

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(contexte).height * 0.75,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              TablTokens.espaceL - 4,
              0,
              TablTokens.espaceL - 4,
              TablTokens.espaceM,
            ),
            children: [
              Text(
                'OÙ CHERCHEZ-VOUS ?',
                style: c.legende.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                  color: c.primaire,
                ),
              ),
              const SizedBox(height: TablTokens.espaceM),
              if (positionConnue)
                ligne(
                  icone: Icons.near_me_outlined,
                  titre: 'Autour de moi',
                  sousTitre: 'Les adresses près de vous',
                  actuelle: false,
                  valeur: autourDeMoi,
                ),
              for (final v in villes)
                ligne(
                  icone: Icons.place_outlined,
                  titre: v.nom,
                  sousTitre: compte(v.compte),
                  actuelle: v.nom == villeActuelle,
                  valeur: v,
                ),
              if (villes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: TablTokens.espaceM,
                  ),
                  child: Text('Pas encore de ville ici.', style: c.legende),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Ce que renvoie « Où cherchez-vous ? » pour « Autour de moi ».
const autourDeMoi = 'autour';
