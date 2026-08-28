import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_cercle.dart';
import 'ecran_commentaires.dart';

const List<String> _moisAnnee = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// Onglet Feed : les souvenirs des gens qu'on suit (et les siens), du
/// plus récent au plus ancien, avec réaction ("j'aime") et commentaires.
/// Pas de wishlist pour l'instant (voir la maquette Claude Design pour
/// la version complète visée, pas encore construite).
class EcranFeed extends StatefulWidget {
  const EcranFeed({
    required this.souvenirService,
    required this.abonnementService,
    super.key,
  });

  final SouvenirService souvenirService;
  final AbonnementService abonnementService;

  @override
  State<EcranFeed> createState() => _EcranFeedState();
}

class _EcranFeedState extends State<EcranFeed> {
  // Calculé une seule fois : cet écran vit dans l'IndexedStack de
  // EcranPrincipal, un changement d'onglet ne doit pas relancer la
  // requête (même raisonnement que le badge de EcranProfil). Mutable
  // (pas `late final`) : une réaction met à jour la liste en place,
  // sans tout recharger.
  late Future<List<SouvenirFeed>> _futurFeed = widget.souvenirService.feed();
  List<SouvenirFeed>? _souvenirs;

  void _allerVersCercle() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EcranCercle(abonnementService: widget.abonnementService),
      ),
    );
  }

  Future<void> _basculerReaction(SouvenirFeed souvenir) async {
    final nouvelEtat = !souvenir.jaiReagi;
    // Optimiste : l'animation et le compteur réagissent tout de suite,
    // sans attendre le réseau — on ne fait pas patienter pour un geste
    // aussi léger.
    _remplacer(
      souvenir.copierAvec(
        jaiReagi: nouvelEtat,
        nombreReactions: souvenir.nombreReactions + (nouvelEtat ? 1 : -1),
      ),
    );
    try {
      await widget.souvenirService.basculerReaction(
        souvenir.id,
        reagir: nouvelEtat,
      );
    } catch (_) {
      // Échec réseau : on revient à l'état d'avant plutôt que de laisser
      // affiché quelque chose qui n'a pas vraiment été enregistré.
      if (!mounted) return;
      _remplacer(souvenir);
      afficherMessage(context, messageErreurGenerique);
    }
  }

  Future<void> _ouvrirCommentaires(SouvenirFeed souvenir) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranCommentaires(
          souvenirService: widget.souvenirService,
          souvenirId: souvenir.id,
        ),
      ),
    );
    // Le nombre de commentaires a pu changer pendant la visite : on
    // recharge tout le Feed au retour plutôt que de suivre les ajouts un
    // par un — plus simple, et cet écran n'est pas quitté souvent.
    if (!mounted) return;
    setState(() {
      _futurFeed = widget.souvenirService.feed();
      _souvenirs = null;
    });
  }

  void _remplacer(SouvenirFeed souvenir) {
    final souvenirs = _souvenirs;
    if (souvenirs == null) return;
    setState(() {
      _souvenirs = [
        for (final s in souvenirs) if (s.id == souvenir.id) souvenir else s,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: SafeArea(
        child: FutureBuilder<List<SouvenirFeed>>(
          future: _futurFeed,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: TablTokens.primaire),
              );
            }
            if (snapshot.hasError) {
              // Le message affiché reste générique côté UI, mais l'erreur
              // réelle part dans les logs — sans ça, un échec silencieux
              // ne laisse rien pour diagnostiquer.
              debugPrint('EcranFeed: ${snapshot.error}\n${snapshot.stackTrace}');
              return Center(
                child: Text(
                  messageErreurGenerique,
                  style: TablTokens.corps.copyWith(
                    color: TablTokens.texteDoux,
                  ),
                ),
              );
            }

            // `??=` : on ne réinitialise pas la liste mutable à chaque
            // rebuild déclenché par une réaction, seulement au premier
            // chargement (ou après un rechargement volontaire).
            final souvenirs = _souvenirs ??= snapshot.data!;
            if (souvenirs.isEmpty) {
              return _EtatVide(onAjouterAmis: _allerVersCercle);
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                TablTokens.espaceM,
                TablTokens.espaceL,
                TablTokens.espaceM,
                TablTokens.espaceXl,
              ),
              itemCount: souvenirs.length,
              itemBuilder: (context, index) {
                final souvenir = souvenirs[index];
                return _CarteSouvenir(
                  souvenir: souvenir,
                  onReagir: () => _basculerReaction(souvenir),
                  onOuvrirCommentaires: () => _ouvrirCommentaires(souvenir),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _EtatVide extends StatelessWidget {
  const _EtatVide({required this.onAjouterAmis});

  final VoidCallback onAjouterAmis;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TablTokens.espaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Votre table est encore vide.',
              textAlign: TextAlign.center,
              style: TablTokens.titre,
            ),
            const SizedBox(height: TablTokens.espaceM),
            Text(
              "Les bonnes adresses prennent vie lorsqu'elles sont partagées "
              'avec les personnes qui comptent vraiment.',
              textAlign: TextAlign.center,
              style: TablTokens.corps.copyWith(color: TablTokens.texteDoux),
            ),
            const SizedBox(height: TablTokens.espaceXl),
            TablBouton(
              libelle: 'Ajouter mes premiers amis',
              onPresse: onAjouterAmis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CarteSouvenir extends StatelessWidget {
  const _CarteSouvenir({
    required this.souvenir,
    required this.onReagir,
    required this.onOuvrirCommentaires,
  });

  final SouvenirFeed souvenir;
  final VoidCallback onReagir;
  final VoidCallback onOuvrirCommentaires;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: TablTokens.espaceL),
      height: 460,
      decoration: BoxDecoration(
        color: TablTokens.surface,
        borderRadius: BorderRadius.circular(TablTokens.arrondiL),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (souvenir.photoUrl != null)
            Image.network(
              souvenir.photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const SizedBox(),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: TablTokens.espaceL,
            right: TablTokens.espaceL,
            bottom: TablTokens.espaceM,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  souvenir.restaurantNom.toUpperCase(),
                  style: TablTokens.legende.copyWith(
                    color: TablTokens.primaire,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                if (souvenir.legende != null) ...[
                  const SizedBox(height: TablTokens.espaceXs),
                  Text(
                    '"${souvenir.legende}"',
                    style: TablTokens.titre.copyWith(
                      fontStyle: FontStyle.italic,
                      color: TablTokens.texte,
                    ),
                  ),
                ],
                const SizedBox(height: TablTokens.espaceS),
                Text(
                  '${souvenir.ville} · ${_momentLisible(souvenir.moment)} · '
                  '${_dateLisible(souvenir.dateVisite)} · par '
                  '${souvenir.auteurPseudo}',
                  style: TablTokens.legende.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: TablTokens.espaceS),
                Row(
                  children: [
                    TablBoutonReaction(
                      actif: souvenir.jaiReagi,
                      onPresse: onReagir,
                    ),
                    if (souvenir.nombreReactions > 0)
                      Text(
                        '${souvenir.nombreReactions}',
                        style: TablTokens.legende.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    const SizedBox(width: TablTokens.espaceM),
                    IconButton(
                      onPressed: onOuvrirCommentaires,
                      icon: const Icon(
                        Icons.mode_comment_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    if (souvenir.nombreCommentaires > 0)
                      Text(
                        '${souvenir.nombreCommentaires}',
                        style: TablTokens.legende.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _momentLisible(String moment) => moment == 'midi' ? 'Midi' : 'Soir';

  String _dateLisible(DateTime date) {
    return '${date.day} ${_moisAnnee[date.month - 1]}';
  }
}
