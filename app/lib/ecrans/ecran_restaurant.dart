import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_publication.dart';

/// La page d'un restaurant — première version, volontairement simple :
/// le restaurant en haut (nom, type, adresse, envie), puis les avis de
/// mon réseau du plus récent au plus ancien, en version compacte (photo
/// à gauche). Un tap ouvre l'avis en entier, comme dans le Feed.
class EcranRestaurant extends StatefulWidget {
  const EcranRestaurant({
    super.key,
    required this.nom,
    required this.sousTitre,
    required this.souvenirService,
    this.restaurantId,
    this.estEnvie = false,
    this.entrerDansTabl,
  });

  final String nom;

  /// "Italien · Rue du Pont 16, Liège".
  final String sousTitre;
  final SouvenirService souvenirService;

  /// `null` pour un lieu qui n'est encore que dans l'annuaire : personne
  /// de mon réseau n'y est allé, il n'y a donc aucun avis à charger.
  final String? restaurantId;
  final bool estEnvie;

  /// Pour un lieu de l'annuaire : le fait entrer dans Tabl et renvoie son
  /// identifiant (nécessaire pour le mettre en envie).
  final Future<String> Function()? entrerDansTabl;

  @override
  State<EcranRestaurant> createState() => _EcranRestaurantState();
}

class _EcranRestaurantState extends State<EcranRestaurant> {
  late String? _restaurantId = widget.restaurantId;
  late bool _estEnvie = widget.estEnvie;
  bool _envieEnCours = false;
  late Future<List<SouvenirFeed>> _futurAvis = _chargerAvis();

  Future<List<SouvenirFeed>> _chargerAvis() {
    final id = _restaurantId;
    return id == null
        ? Future.value(const [])
        : widget.souvenirService.souvenirsDuRestaurant(id);
  }

  void _recharger() => setState(() => _futurAvis = _chargerAvis());

  Future<void> _ouvrirAvis(SouvenirFeed avis) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranPublication(
          souvenir: avis,
          souvenirService: widget.souvenirService,
        ),
      ),
    );
    // Réactions, commentaires ou envie ont pu changer.
    if (mounted) _recharger();
  }

  Future<void> _basculerEnvie() async {
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
    } catch (e) {
      debugPrint('EcranRestaurant: envie : $e');
      if (mounted) afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => _envieEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: SafeArea(
        child: FutureBuilder<List<SouvenirFeed>>(
          future: _futurAvis,
          builder: (context, snapshot) {
            final avis = snapshot.data;
            return ListView(
              padding: const EdgeInsets.only(bottom: TablTokens.espaceXl),
              children: [
                _enTete(avis),
                if (snapshot.hasError)
                  const _Message(texte: messageErreurGenerique)
                else if (avis == null)
                  const Padding(
                    padding: EdgeInsets.all(TablTokens.espaceXl),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: TablTokens.primaire,
                      ),
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
                    TablLigneAvis(
                      auteurPseudo: a.auteurPseudo,
                      auteurPhotoUrl: a.auteurPhotoUrl,
                      dateLisible: dateLisibleSouvenir(a.dateVisite),
                      photoUrl: a.photoUrl,
                      emoji: a.emotion?.emoji,
                      legende: a.legende,
                      resumeReactions: a.nombreReactions == 0
                          ? null
                          : libelleReactionsSouvenir(a),
                      onPresse: () => _ouvrirAvis(a),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _enTete(List<SouvenirFeed>? avis) {
    final nombre = avis?.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceM,
        TablTokens.espaceS,
        TablTokens.espaceL,
        TablTokens.espaceM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TablBoutonRetour(onPresse: () => Navigator.of(context).pop()),
          const SizedBox(height: TablTokens.espaceM),
          Padding(
            padding: const EdgeInsets.only(left: TablTokens.espaceS),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.nom, style: TablTokens.grandTitre),
                if (widget.sousTitre.isNotEmpty) ...[
                  const SizedBox(height: TablTokens.espaceXs),
                  Text(
                    widget.sousTitre,
                    style: TablTokens.corps.copyWith(
                      color: TablTokens.texteDoux,
                    ),
                  ),
                ],
                const SizedBox(height: TablTokens.espaceM),
                Row(
                  children: [
                    TablPuceFiltre(
                      libelle: _estEnvie
                          ? 'Dans mes envies'
                          : 'Ajouter à mes envies',
                      actif: _estEnvie,
                      onPresse: _envieEnCours ? () {} : _basculerEnvie,
                    ),
                  ],
                ),
                if (nombre != null && nombre > 0) ...[
                  const SizedBox(height: TablTokens.espaceL),
                  Text(
                    nombre == 1
                        ? '1 avis de votre réseau'
                        : '$nombre avis de votre réseau',
                    style: TablTokens.sousTitre,
                  ),
                ],
              ],
            ),
          ),
        ],
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
