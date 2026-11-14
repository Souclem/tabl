import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'feuille_choix_restaurant.dart';
import 'recherche_lieu_en_direct.dart';

/// Ce que « Où et quand » rend : le lieu choisi (`null` : aucun), et le
/// moment du repas (`matin` / `midi` / `soir`), `null` quand il n'est pas
/// modifiable.
typedef ResultatOuEtQuand = ({LieuRestaurant? lieu, String? moment});

/// Ce qu'on écrit soi-même : un restaurant qui n'est pas dans Tabl, chez
/// quelqu'un hors Tabl, ou un « chez personne » à soi.
enum _Saisie { restaurant, chez, ailleurs }

/// « Où et quand » : le lieu du repas et, pour un moment en création, le
/// moment du repas (petit-déjeuner, déjeuner ou dîner).
///
/// Tout se passe dans la feuille. Le restaurant d'abord : le plus probable
/// (d'après les photos, sinon là où l'on est) arrive déjà coché, dans une
/// liste qui défile ; toucher une autre ligne la coche et replie la liste
/// sur ce choix (« Voir les autres restaurants » la rouvre). La recherche
/// cherche au fil de la frappe, « Pas dans Tabl ? » laisse l'écrire (et
/// placer soi-même son épingle).
/// Pour le reste, la maison à droite de la recherche : la feuille se
/// réchauffe (en fondu) et propose, dans une rangée qui défile de côté, Chez moi, les
/// personnes que je suis ([personnesSuivies], celles de [prioritairesIds]
/// d'abord), mes lieux et « Chez… » quelqu'un qui n'est pas sur Tabl ;
/// puis « Chez personne » (pique-nique…). La feuille garde la même hauteur
/// quel que soit le nombre de personnes, et le moment du repas reste en
/// bas. Hors restaurant, rien n'est jamais localisé.
///
/// « OK » ferme avec le résultat. `null` : fermée sans rien changer.
/// [moment] : `null` pour un moment déjà publié, dont la date est figée.
Future<ResultatOuEtQuand?> ouvrirFeuilleOuEtQuand(
  BuildContext context, {
  required LieuRestaurant? lieu,
  required String? moment,
  required List<Coordonnees> endroits,
  required List<List<LieuRestaurant>> prochesParEndroit,
  required RepereDistance repere,
  required RechercheLieuService? rechercheLieuService,
  required PositionService? positionService,
  Future<List<ProfilPublic>>? personnesSuivies,
  Set<String> prioritairesIds = const {},
}) {
  return showModalBottomSheet<ResultatOuEtQuand>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: voileFeuilleCreation,
    builder: (_) => _FeuilleOuEtQuand(
      lieu: lieu,
      moment: moment,
      endroits: endroits,
      prochesParEndroit: prochesParEndroit,
      repere: repere,
      rechercheLieuService: rechercheLieuService,
      positionService: positionService,
      personnesSuivies: personnesSuivies,
      prioritairesIds: prioritairesIds,
    ),
  );
}

class _FeuilleOuEtQuand extends StatefulWidget {
  const _FeuilleOuEtQuand({
    required this.lieu,
    required this.moment,
    required this.endroits,
    required this.prochesParEndroit,
    required this.repere,
    required this.rechercheLieuService,
    required this.positionService,
    required this.personnesSuivies,
    required this.prioritairesIds,
  });

  final LieuRestaurant? lieu;
  final String? moment;
  final List<Coordonnees> endroits;
  final List<List<LieuRestaurant>> prochesParEndroit;
  final RepereDistance repere;
  final RechercheLieuService? rechercheLieuService;
  final PositionService? positionService;
  final Future<List<ProfilPublic>>? personnesSuivies;
  final Set<String> prioritairesIds;

  @override
  State<_FeuilleOuEtQuand> createState() => _FeuilleOuEtQuandState();
}

class _FeuilleOuEtQuandState extends State<_FeuilleOuEtQuand>
    with RechercheLieuEnDirect<_FeuilleOuEtQuand> {
  @override
  RechercheLieuService? get rechercheLieuService => widget.rechercheLieuService;

  /// La recherche se trie autour des photos, sinon de là où l'on est.
  @override
  PositionService? get positionService => widget.endroits.isNotEmpty
      ? PositionFixe(widget.endroits.first)
      : widget.positionService;

  late String? _moment = widget.moment;
  late LieuRestaurant? _choix = widget.lieu;

  /// La maison touchée : on n'était pas au restaurant.
  late bool _maison = widget.lieu?.personnel ?? false;

  /// Un restaurant touché : la liste se replie sur lui.
  bool _replie = false;

  /// Côté maison, on cherche une personne ([recherche] cherche un
  /// restaurant).
  final _recherchePersonne = TextEditingController();

  /// Ce qu'on est en train d'écrire, et où.
  _Saisie? _saisie;
  final _nom = TextEditingController();
  final _ville = TextEditingController();
  String? _erreurNom;
  String? _erreurVille;

  /// L'épingle du restaurant écrit à la main, placée par soi-même.
  Coordonnees? _epingle;

  List<ProfilPublic> _suivis = const [];

  /// Mes lieux personnels déjà enregistrés (« Chez Mamie », « Au bord du
  /// lac »), jamais ceux d'un autre.
  List<LieuRestaurant> _mesLieux = const [];

  @override
  void initState() {
    super.initState();
    widget.personnesSuivies?.then((suivis) {
      if (mounted) setState(() => _suivis = suivis);
    }, onError: (Object e) => debugPrint('OuEtQuand: personnes : $e'));
    _chargerMesLieux();
  }

  Future<void> _chargerMesLieux() async {
    try {
      final mesLieux = await widget.rechercheLieuService?.mesLieuxPersonnels();
      if (mounted && mesLieux != null) setState(() => _mesLieux = mesLieux);
    } catch (e) {
      debugPrint('OuEtQuand: mes lieux : $e');
    }
  }

  @override
  void dispose() {
    _recherchePersonne.dispose();
    _nom.dispose();
    _ville.dispose();
    super.dispose();
  }

  bool _coche(LieuRestaurant lieu) => _choix?.cle == lieu.cle;

  void _choisir(LieuRestaurant lieu) => setState(() {
    _choix = lieu;
    _saisie = null;
    _erreurNom = null;
    _erreurVille = null;
  });

  /// Un restaurant touché : coché, la recherche effacée, la liste repliée
  /// sur lui.
  void _choisirRestaurant(LieuRestaurant lieu) {
    FocusScope.of(context).unfocus();
    recherche.clear();
    _choisir(lieu);
    setState(() {
      suggestions = const [];
      _replie = true;
    });
  }

  void _basculerMaison() => setState(() {
    _maison = !_maison;
    _saisie = null;
    FocusScope.of(context).unfocus();
  });

  String _detail(LieuRestaurant lieu) => detailLieuSouvenir(
    lieu,
    repere: widget.endroits.isEmpty ? null : widget.repere,
  );

  /// Sa distance à l'endroit le plus proche, quand il y en a.
  LieuRestaurant _aDistance(LieuRestaurant lieu) => widget.endroits.isEmpty
      ? lieu
      : aDistanceDesEndroits(lieu, widget.endroits);

  void _ecrire(_Saisie saisie) => setState(() {
    _saisie = saisie;
    _erreurNom = null;
    _erreurVille = null;
    _epingle = null;
    _ville.clear();
    // Le restaurant cherché sans le trouver : son nom est déjà là.
    _nom.text = saisie == _Saisie.restaurant ? recherche.text.trim() : '';
  });

  /// « Chez… » ou « Autre » : le nom écrit devient le lieu choisi.
  void _validerNom() {
    final saisie = _saisie;
    if (saisie == null || saisie == _Saisie.restaurant) return;
    final resultat = lieuPersonnelSaisi(
      _nom.text,
      saisie == _Saisie.chez ? GenreLieu.chez : GenreLieu.ailleurs,
      mesLieux: _mesLieux,
    );
    final lieu = resultat.lieu;
    if (lieu == null) {
      setState(() => _erreurNom = resultat.erreur);
      return;
    }
    FocusScope.of(context).unfocus();
    _choisir(lieu);
  }

  /// Un restaurant qui n'est pas dans Tabl : son nom, sa ville, et sa
  /// position seulement si l'on a placé l'épingle.
  void _validerRestaurant() {
    final erreurNom = ValidationSouvenir.nomRestaurant(_nom.text);
    final erreurVille = ValidationSouvenir.ville(_ville.text);
    setState(() {
      _erreurNom = erreurNom;
      _erreurVille = erreurVille;
    });
    if (erreurNom != null || erreurVille != null) return;
    _choisirRestaurant(
      LieuRestaurant.manuel(
        nom: _nom.text.trim(),
        ville: _ville.text.trim(),
        latitude: _epingle?.latitude,
        longitude: _epingle?.longitude,
      ),
    );
  }

  Future<void> _placerEpingle() async {
    FocusScope.of(context).unfocus();
    final placee = await placerEpingle(
      context,
      nom: _nom.text,
      depart: departEpingle(
        epingle: _epingle,
        endroits: widget.endroits,
        position: position,
      ),
      reperes: widget.endroits,
    );
    if (placee != null && mounted) setState(() => _epingle = placee);
  }

  void _fermer() {
    // Ce qui est écrit sans avoir été validé n'est pas perdu.
    switch (_saisie) {
      case _Saisie.restaurant
          when _nom.text.trim().isNotEmpty || _ville.text.trim().isNotEmpty:
        _validerRestaurant();
      case _Saisie.chez || _Saisie.ailleurs when _nom.text.trim().isNotEmpty:
        _validerNom();
      default:
        break;
    }
    if (_erreurNom != null || _erreurVille != null) return;
    Navigator.of(context).pop((lieu: _choix, moment: _moment));
  }

  @override
  Widget build(BuildContext context) {
    final moment = _moment;
    return TablCadreFeuilleCreation(
      titre: 'Où et quand',
      libelleAction: 'OK',
      onAction: _fermer,
      chaud: _maison,
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _rangeeRecherche(),
          // La maison touchée : les listes changent en fondu, la feuille
          // grandit ou rétrécit en douceur.
          AnimatedSize(
            duration: _duree(280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: _duree(260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (enfant, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.03),
                    end: Offset.zero,
                  ).animate(animation),
                  child: enfant,
                ),
              ),
              layoutBuilder: (actuel, precedents) => Stack(
                alignment: Alignment.topCenter,
                children: [...precedents, ?actuel],
              ),
              child: Column(
                key: ValueKey(_maison),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _maison ? _partieMaison() : _partieRestaurant(),
              ),
            ),
          ),
          const SizedBox(height: TablTokens.espaceXs),
        ],
      ),
      // Toujours visible, quelle que soit la longueur des listes.
      pied: moment == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const TablRubriqueCreation('Moment du repas'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final m in momentsRepas)
                      TablPastilleCreation(
                        libelle: libelleMomentRepas(m)!,
                        choisie: moment == m,
                        onPresse: () => setState(() => _moment = m),
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  /// Rien d'animé quand on a réduit les animations.
  Duration _duree(int ms) => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: ms);

  /// La recherche (un restaurant, ou une personne côté maison) et la
  /// maison à sa droite.
  Widget _rangeeRecherche() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: AnimatedSwitcher(
          duration: _duree(200),
          child: _maison
              ? TablRechercheCreation(
                  key: const ValueKey('personne'),
                  controleur: _recherchePersonne,
                  indication: 'Chercher une personne',
                  onChanged: (_) => setState(() {}),
                )
              : TablRechercheCreation(
                  key: const ValueKey('restaurant'),
                  controleur: recherche,
                  indication: 'Chercher un restaurant',
                  onChanged: (texte) {
                    setState(() {});
                    rechercherAvecAttente(texte);
                  },
                ),
        ),
      ),
      const SizedBox(width: 8),
      TablBoutonMaisonCreation(actif: _maison, onPresse: _basculerMaison),
    ],
  );

  Widget _mot(String texte) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      texte,
      style: TablTokens.policeCreation.copyWith(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: TablCouleurs.sombre.texte.withValues(alpha: 0.6),
      ),
    ),
  );

  Widget _ligneRestaurant(LieuRestaurant l) => TablOptionCreation(
    titre: l.nom,
    detail: _detail(l),
    initiales: initialesLieu(l.nom),
    coche: _coche(l),
    // Retoucher le choix, liste repliée : elle se rouvre.
    onPresse: () => _replie && _coche(l)
        ? setState(() => _replie = false)
        : _choisirRestaurant(l),
  );

  List<Widget> _partieRestaurant() {
    final choix = _choix;
    final cherche = recherche.text.trim().length >= 2;
    final List<Widget> liste;
    if (cherche) {
      final trouves = [for (final l in suggestions) _aDistance(l)];
      liste = [
        for (final l in trouves) _ligneRestaurant(l),
        if (trouves.isEmpty && !rechercheEnCours)
          _mot('Aucun restaurant trouvé.'),
      ];
    } else {
      // Les restaurants près des photos (chacun une fois) ; celui choisi
      // ailleurs (par la recherche, ou écrit à la main) en tête.
      final proches = <LieuRestaurant>[];
      for (final l in widget.prochesParEndroit.expand((e) => e)) {
        if (!proches.any((p) => p.cle == l.cle)) proches.add(l);
      }
      final lignes = [
        if (choix != null &&
            !choix.personnel &&
            !proches.any((l) => l.cle == choix.cle))
          choix,
        ...proches,
      ];
      final replie = _replie && choix != null && !choix.personnel;
      liste = replie
          ? [
              const TablRubriqueCreation('Votre choix'),
              _ligneRestaurant(choix),
              if (lignes.length > 1)
                TablOptionCreation(
                  titre: 'Voir les autres restaurants',
                  icone: Icons.expand_more_rounded,
                  onPresse: () => setState(() => _replie = false),
                ),
            ]
          : [
              if (lignes.isNotEmpty)
                TablRubriqueCreation(
                  proches.isEmpty
                      ? 'Votre choix'
                      : widget.repere == RepereDistance.vous
                      ? 'Près de vous'
                      : 'Près de vos photos',
                ),
              for (final l in lignes) _ligneRestaurant(l),
            ];
    }
    return [
      if (rechercheEnCours)
        LinearProgressIndicator(
          minHeight: 2,
          color: TablCouleurs.sombre.primaire,
          backgroundColor: Colors.transparent,
        ),
      ...liste,
      if (_saisie == _Saisie.restaurant)
        ..._saisieRestaurant()
      else
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: TablOptionCreation(
            titre: 'Pas dans Tabl ?',
            detail: 'Ajoutez-le',
            icone: Icons.add_rounded,
            onPresse: () => _ecrire(_Saisie.restaurant),
          ),
        ),
    ];
  }

  List<Widget> _saisieRestaurant() => [
    const TablRubriqueCreation('Pas dans Tabl'),
    TablRechercheCreation(
      controleur: _nom,
      indication: 'Nom du restaurant',
      icone: Icons.storefront_outlined,
      autofocus: _nom.text.isEmpty,
      actionClavier: TextInputAction.next,
      erreur: _erreurNom,
      onChanged: (_) {
        if (_erreurNom != null) setState(() => _erreurNom = null);
      },
    ),
    TablRechercheCreation(
      controleur: _ville,
      indication: 'Ville',
      icone: Icons.location_city_outlined,
      autofocus: _nom.text.isNotEmpty,
      actionClavier: TextInputAction.done,
      erreur: _erreurVille,
      onChanged: (_) {
        if (_erreurVille != null) setState(() => _erreurVille = null);
      },
      onSoumis: (_) => _validerRestaurant(),
    ),
    const SizedBox(height: 4),
    Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        // Sans épingle, il n'ira sur aucune carte.
        TablPastilleCreation(
          libelle: _epingle == null ? 'Placer sur la carte' : 'Sur la carte',
          choisie: _epingle != null,
          onPresse: _placerEpingle,
        ),
        TablPastilleCreation(
          libelle: 'Ajouter',
          choisie: false,
          onPresse: _validerRestaurant,
        ),
      ],
    ),
  ];

  List<Widget> _partieMaison() {
    final recherche = _recherchePersonne.text;
    final cherche = recherche.trim().isNotEmpty;
    final texte = normaliserPourRecherche(recherche.trim());
    final choix = _choix;
    final personnes = personnesChezQui(
      _suivis,
      recherche: recherche,
      prioritairesIds: widget.prioritairesIds,
      choisieId: choix?.hoteId,
    );
    final chezMesLieux = [
      for (final l in _mesLieux)
        if (l.genre == GenreLieu.chez &&
            (!cherche || normaliserPourRecherche(l.nom).contains(texte)))
          l,
    ];
    // Les « chez personne » proposés, puis les miens.
    final ailleurs = [
      for (final nom in lieuxAilleurs)
        LieuRestaurant.personnel(nom: nom, genre: GenreLieu.ailleurs),
      for (final l in _mesLieux)
        if (l.genre == GenreLieu.ailleurs &&
            !lieuxAilleurs.any(
              (nom) =>
                  normaliserPourRecherche(nom) ==
                  normaliserPourRecherche(l.nom),
            ))
          l,
    ];
    // Choisi avant d'ouvrir la feuille, mais hors des listes (un ancien
    // lieu de nom libre, par exemple).
    final choixHorsListe =
        choix != null &&
        choix.personnel &&
        choix.genre != GenreLieu.domicile &&
        choix.hoteId == null &&
        !chezMesLieux.any(_coche) &&
        !ailleurs.any(_coche);
    final saisie = _saisie;
    final ronds = [
      if (!cherche)
        TablRondChoixCreation(
          libelle: 'Chez moi',
          icone: Icons.home_outlined,
          choisi: _coche(const LieuRestaurant.domicile()),
          onPresse: () => _choisir(const LieuRestaurant.domicile()),
        ),
      for (final p in personnes)
        TablRondChoixCreation(
          libelle: p.pseudo,
          semantique: 'Chez ${p.pseudo}',
          avatar: TablAvatar(pseudo: p.pseudo, photoUrl: p.photoUrl, rayon: 24),
          choisi: choix?.hoteId == p.id,
          onPresse: () => _choisir(
            LieuRestaurant.chezQuelquun(
              hoteId: p.id,
              hotePseudo: p.pseudo,
              hotePhotoUrl: p.photoUrl,
            ),
          ),
        ),
      for (final l in chezMesLieux)
        TablRondChoixCreation(
          libelle: nomSansChez(l.nom),
          semantique: l.nom,
          icone: Icons.home_outlined,
          choisi: _coche(l),
          onPresse: () => _choisir(l),
        ),
      if (choixHorsListe && choix.genre == GenreLieu.chez)
        TablRondChoixCreation(
          libelle: nomSansChez(choix.nom),
          semantique: choix.nom,
          icone: Icons.home_outlined,
          choisi: true,
          onPresse: () {},
        ),
      TablRondChoixCreation(
        libelle: 'Chez…',
        semantique: 'Chez quelqu\'un qui n\'est pas sur Tabl',
        icone: Icons.add_rounded,
        choisi: saisie == _Saisie.chez,
        onPresse: () => _ecrire(_Saisie.chez),
      ),
    ];
    return [
      // Une rangée qui défile de côté : la feuille garde sa hauteur, même
      // avec beaucoup de monde.
      SizedBox(
        height: TablRondChoixCreation.hauteur(context) + 8,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(top: 8),
          itemCount: ronds.length,
          separatorBuilder: (_, _) => const SizedBox(width: 4),
          itemBuilder: (_, i) => ronds[i],
        ),
      ),
      if (saisie == _Saisie.chez)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _champNom('Mamie, mes parents…'),
        ),
      const TablRubriqueCreation('Chez personne'),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final l in ailleurs)
            TablPastilleCreation(
              libelle: l.nom,
              choisie: _coche(l),
              onPresse: () => _choisir(l),
            ),
          if (choixHorsListe && choix.genre == GenreLieu.ailleurs)
            TablPastilleCreation(
              libelle: choix.nom,
              choisie: true,
              onPresse: () {},
            ),
          TablPastilleCreation(
            libelle: 'Autre',
            choisie: saisie == _Saisie.ailleurs,
            onPresse: () => _ecrire(_Saisie.ailleurs),
          ),
        ],
      ),
      if (saisie == _Saisie.ailleurs)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _champNom('Au bord du lac, en randonnée…'),
        ),
    ];
  }

  Widget _champNom(String indication) => TablRechercheCreation(
    controleur: _nom,
    indication: indication,
    icone: Icons.edit_outlined,
    autofocus: true,
    actionClavier: TextInputAction.done,
    erreur: _erreurNom,
    onChanged: (_) {
      if (_erreurNom != null) setState(() => _erreurNom = null);
    },
    onSoumis: (_) => _validerNom(),
  );
}
