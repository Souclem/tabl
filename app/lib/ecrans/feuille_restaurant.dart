import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'actions_publications.dart';

/// Les tailles de la feuille d'un restaurant, en fraction de la hauteur
/// disponible : réduite (l'en-tête seulement) et ouverte.
const tailleFeuilleReduite = 0.34;
const tailleFeuilleOuverte = 0.94;

/// Ouvre la feuille d'un restaurant par-dessus l'écran courant (Feed,
/// Profil, liste de la carte) : une sous-page, pas une nouvelle page.
Future<void> ouvrirFeuilleRestaurant(
  BuildContext context, {
  required String nom,
  required String sousTitre,
  required SouvenirService souvenirService,
  String? restaurantId,
  String? resume,
  bool estEnvie = false,
  Future<String> Function()? entrerDansTabl,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: tailleFeuilleOuverte,
      maxChildSize: tailleFeuilleOuverte,
      minChildSize: 0.4,
      expand: false,
      builder: (contexteFeuille, defilement) => FeuilleRestaurant(
        nom: nom,
        sousTitre: sousTitre,
        resume: resume,
        restaurantId: restaurantId,
        estEnvie: estEnvie,
        entrerDansTabl: entrerDansTabl,
        souvenirService: souvenirService,
        defilement: defilement,
        onFermer: () => Navigator.of(contexteFeuille).pop(),
      ),
    ),
  );
}

/// Le contenu de la page d'un restaurant, dans une feuille qui monte du
/// bas : en haut le restaurant (nom, type, qui y est allé, envie), puis
/// les avis de mon réseau du plus récent au plus ancien, en version
/// compacte (photo à gauche). Un tap sur un avis l'agrandit sur place en
/// publication complète, comme dans le Feed — jamais une autre page.
class FeuilleRestaurant extends StatefulWidget {
  const FeuilleRestaurant({
    super.key,
    required this.nom,
    required this.sousTitre,
    required this.souvenirService,
    required this.defilement,
    this.resume,
    this.restaurantId,
    this.estEnvie = false,
    this.entrerDansTabl,
    this.onFermer,
    this.onToucherEntete,
    this.onEnvieChangee,
  });

  final String nom;

  /// "Italien · Rue du Pont 16, Liège".
  final String sousTitre;

  /// "Emma et 2 autres y sont allés", si connu.
  final String? resume;
  final SouvenirService souvenirService;

  /// Le défilement de la feuille (fourni par DraggableScrollableSheet).
  final ScrollController defilement;

  /// `null` pour un lieu qui n'est encore que dans l'annuaire : aucun avis.
  final String? restaurantId;
  final bool estEnvie;

  /// Pour un lieu de l'annuaire : le fait entrer dans Tabl et renvoie son
  /// identifiant (nécessaire pour le mettre en envie).
  final Future<String> Function()? entrerDansTabl;
  final VoidCallback? onFermer;

  /// Tap sur l'en-tête — sur la carte, agrandit la feuille réduite.
  final VoidCallback? onToucherEntete;

  /// L'envie a changé (la carte se met à jour).
  final ValueChanged<bool>? onEnvieChangee;

  @override
  State<FeuilleRestaurant> createState() => _FeuilleRestaurantState();
}

class _FeuilleRestaurantState extends State<FeuilleRestaurant>
    with ActionsPublications<FeuilleRestaurant> {
  late String? _restaurantId = widget.restaurantId;
  late bool _estEnvie = widget.estEnvie;
  bool _envieEnCours = false;
  bool _chargement = true;
  bool _erreur = false;

  /// L'avis agrandi en publication complète, s'il y en a un.
  String? _ouvert;

  @override
  SouvenirService get souvenirService => widget.souvenirService;

  @override
  void initState() {
    super.initState();
    recharger();
  }

  @override
  Future<void> recharger() async {
    final id = _restaurantId;
    if (id == null) {
      setState(() {
        souvenirs = const [];
        _chargement = false;
      });
      return;
    }
    try {
      final avis = await widget.souvenirService.souvenirsDuRestaurant(id);
      if (!mounted) return;
      setState(() {
        souvenirs = avis;
        _chargement = false;
        _erreur = false;
      });
    } catch (e) {
      debugPrint('FeuilleRestaurant: $e');
      if (mounted) setState(() => _erreur = true);
    }
  }

  Future<void> _basculerEnvieRestaurant() async {
    setState(() => _envieEnCours = true);
    try {
      final id = _restaurantId ?? await widget.entrerDansTabl?.call();
      if (id == null) return;
      final envie = !_estEnvie;
      await widget.souvenirService.basculerEnvie(id, envie: envie);
      if (!mounted) return;
      setState(() {
        _restaurantId = id;
        _estEnvie = envie;
      });
      widget.onEnvieChangee?.call(envie);
    } catch (e) {
      debugPrint('FeuilleRestaurant: envie : $e');
      if (mounted) afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => _envieEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avis = souvenirs ?? const <SouvenirFeed>[];
    return Material(
      color: TablTokens.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(TablTokens.arrondiL),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        controller: widget.defilement,
        padding: const EdgeInsets.only(bottom: TablTokens.espaceXl),
        children: [
          _enTete(avis.length),
          if (_erreur)
            const _Message(texte: messageErreurGenerique)
          else if (_chargement)
            const Padding(
              padding: EdgeInsets.all(TablTokens.espaceXl),
              child: Center(
                child: CircularProgressIndicator(color: TablTokens.primaire),
              ),
            )
          else if (avis.isEmpty)
            const _Message(
              texte:
                  'Personne de votre réseau n\'y est encore allé. '
                  'Ajoutez-le à vos envies pour ne pas l\'oublier.',
            )
          else
            for (final a in avis)
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _ouvert == a.id ? _avisOuvert(a) : _avisReduit(a),
              ),
        ],
      ),
    );
  }

  Widget _avisReduit(SouvenirFeed a) {
    return TablLigneAvis(
      auteurPseudo: a.auteurPseudo,
      auteurPhotoUrl: a.auteurPhotoUrl,
      dateLisible: dateLisibleSouvenir(a.dateVisite),
      photoUrl: a.photoUrl,
      emoji: a.emotion?.emoji,
      legende: a.legende,
      resumeReactions: a.nombreReactions == 0
          ? null
          : libelleReactionsSouvenir(a),
      onPresse: () => setState(() => _ouvert = a.id),
    );
  }

  Widget _avisOuvert(SouvenirFeed a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() => _ouvert = null),
            icon: const Icon(Icons.expand_less_rounded, size: 18),
            label: const Text('Réduire'),
            style: TextButton.styleFrom(foregroundColor: TablTokens.texteDoux),
          ),
        ),
        construirePublication(
          a,
          contexte: ContextePublication.feed,
          // On est déjà sur ce restaurant.
          onOuvrirLieu: () {},
        ),
      ],
    );
  }

  Widget _enTete(int nombreAvis) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onToucherEntete,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TablTokens.espaceL,
          TablTokens.espaceS,
          TablTokens.espaceS,
          TablTokens.espaceM,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: TablTokens.bordure,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: TablTokens.espaceM),
                    child: Text(widget.nom, style: TablTokens.titre),
                  ),
                ),
                if (widget.onFermer != null)
                  IconButton(
                    onPressed: widget.onFermer,
                    tooltip: 'Fermer',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: TablTokens.texteDoux,
                  ),
              ],
            ),
            if (widget.sousTitre.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(widget.sousTitre, style: TablTokens.legende),
              ),
            if (widget.resume != null)
              Padding(
                padding: const EdgeInsets.only(top: TablTokens.espaceS),
                child: Text(
                  widget.resume!,
                  style: TablTokens.legende.copyWith(
                    color: TablTokens.primaire,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: TablTokens.espaceM),
            TablPuceFiltre(
              libelle: _estEnvie ? 'Dans mes envies' : 'Ajouter à mes envies',
              actif: _estEnvie,
              onPresse: _envieEnCours ? () {} : _basculerEnvieRestaurant,
            ),
            if (nombreAvis > 0) ...[
              const SizedBox(height: TablTokens.espaceL),
              Text(
                nombreAvis == 1
                    ? '1 avis de votre réseau'
                    : '$nombreAvis avis de votre réseau',
                style: TablTokens.sousTitre,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TablTokens.espaceXl),
      child: Text(
        texte,
        textAlign: TextAlign.center,
        style: TablTokens.corps.copyWith(color: TablTokens.texteDoux),
      ),
    );
  }
}
