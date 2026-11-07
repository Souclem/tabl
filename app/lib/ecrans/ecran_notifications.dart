import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'actions_publications.dart';
import 'ecran_repondre_avis.dart';
import 'feuille_restaurant.dart';
import 'page_moment.dart';

/// La cloche du Feed : ce qui m'est arrivé. En tête, les demandes de
/// suivi (on y répond sur place) ; puis les nouvelles depuis ma dernière
/// visite, et le reste. Un j'aime ou un commentaire ouvre le moment
/// concerné, le reste ouvre le profil de la personne. Ouvrir l'écran
/// marque tout comme vu.
class EcranNotifications extends StatefulWidget {
  const EcranNotifications({
    super.key,
    required this.notificationService,
    required this.abonnementService,
    required this.souvenirService,
    this.avisService,
  });

  final NotificationService notificationService;
  final AbonnementService abonnementService;
  final SouvenirService souvenirService;

  /// Pour répondre aux demandes d'avis. `null` : elles ouvrent le profil.
  final AvisService? avisService;

  @override
  State<EcranNotifications> createState() => _EcranNotificationsState();
}

class _EcranNotificationsState extends State<EcranNotifications>
    with ActionsPublications<EcranNotifications> {
  List<LigneNotification>? _demandes;
  List<LigneNotification> _autres = const [];
  bool _erreur = false;

  /// Les demandes auxquelles on vient de répondre : elles disparaissent
  /// tout de suite, sans attendre la base.
  final Set<String> _repondues = {};

  @override
  SouvenirService get souvenirService => widget.souvenirService;

  @override
  AbonnementService? get abonnementService => widget.abonnementService;

  @override
  void initState() {
    super.initState();
    recharger();
  }

  @override
  Future<void> recharger() async {
    try {
      final (:notifications, :vuesLe) = await widget.notificationService
          .mesNotifications();
      if (!mounted) return;
      final rangees = rangerNotifications(notifications, vuesLe: vuesLe);
      setState(() {
        _demandes = rangees.demandes;
        _autres = rangees.autres;
        _erreur = false;
      });
      // Vu : la pastille de la cloche s'éteint. Les nouvelles restent
      // marquées pendant cette visite.
      final plusRecente = notifications.firstOrNull?.creeLe;
      if (plusRecente != null &&
          (vuesLe == null || plusRecente.isAfter(vuesLe))) {
        widget.notificationService.marquerVues(DateTime.now()).catchError((
          Object e,
        ) {
          debugPrint('EcranNotifications: vues : $e');
        });
      }
    } catch (e) {
      debugPrint('EcranNotifications: $e');
      if (mounted) setState(() => _erreur = true);
    }
  }

  Future<void> _repondre(LigneNotification l, {required bool accepter}) async {
    final id = l.acteur.id;
    setState(() => _repondues.add(id));
    try {
      if (accepter) {
        await widget.abonnementService.accepterDemande(id);
      } else {
        await widget.abonnementService.refuserDemande(id);
      }
      if (!mounted) return;
      afficherMessage(
        context,
        accepter
            ? '${l.acteur.pseudo} vous suit désormais.'
            : 'Demande refusée.',
      );
      recharger();
    } catch (e) {
      debugPrint('EcranNotifications: réponse : $e');
      if (!mounted) return;
      setState(() => _repondues.remove(id));
      afficherMessage(context, messageErreurGenerique);
    }
  }

  /// Répondre à une demande d'avis, sur son propre écran.
  Future<void> _repondreAvis(LigneNotification l) async {
    final service = widget.avisService;
    final demandeId = l.demandeId;
    if (service == null || demandeId == null) return;
    final repondu = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EcranRepondreAvis(
          avisService: service,
          demandeId: demandeId,
          demandeur: l.acteur.pseudo,
          demandeurPhotoUrl: l.acteur.photoUrl,
          question: l.texte ?? questionAvis(l.restaurantNom ?? 'ce restaurant'),
          restaurantNom: l.restaurantNom,
        ),
      ),
    );
    if (repondu == true && mounted) recharger();
  }

  Future<void> _ouvrir(LigneNotification l) async {
    if (l.type == TypeNotification.demandeAvis && widget.avisService != null) {
      await _repondreAvis(l);
      return;
    }
    final restaurantId = l.restaurantId;
    if (l.type == TypeNotification.avisRecu && restaurantId != null) {
      await ouvrirFeuilleRestaurant(
        context,
        nom: l.restaurantNom ?? '',
        sousTitre: '',
        restaurantId: restaurantId,
        souvenirService: widget.souvenirService,
        abonnementService: widget.abonnementService,
        avisService: widget.avisService,
      );
      return;
    }
    final souvenirId = l.souvenirId;
    if (souvenirId == null) {
      await ouvrirProfilDe(l.acteur.id, l.acteur.pseudo);
      return;
    }
    try {
      final souvenir = await widget.souvenirService.souvenir(souvenirId);
      if (!mounted) return;
      if (souvenir == null) {
        afficherMessage(context, 'Ce moment n\'est plus disponible.');
        return;
      }
      await ouvrirPageMoment(
        context,
        souvenir: souvenir,
        cleHero: 'notification-$souvenirId-${l.creeLe}',
        souvenirService: widget.souvenirService,
        onReagir: basculerReaction,
        onOuvrirLieu: ouvrirRestaurant,
        onOuvrirPersonne: (p) => ouvrirProfilDe(p.id, p.pseudo),
      );
    } catch (e) {
      debugPrint('EcranNotifications: moment : $e');
      if (mounted) afficherMessage(context, messageErreurGenerique);
    }
  }

  Widget _ligne(LigneNotification l) {
    final demande = l.type == TypeNotification.demandeSuivi;
    final avis =
        l.type == TypeNotification.demandeAvis && widget.avisService != null;
    return TablLigneNotification(
      key: ValueKey(
        '${l.type.valeur}-${l.acteur.id}-${l.souvenirId}-${l.creeLe}',
      ),
      visages: [
        for (final a in l.acteurs.take(2))
          BullePersonne(pseudo: a.pseudo, photoUrl: a.photoUrl),
      ],
      phrase: phraseNotification(l),
      quand: dateLisibleCommentaire(l.creeLe),
      nouvelle: l.nouvelle && !demande && !avis,
      vignetteUrl: l.souvenirPhotoUrl,
      onPresse: () => _ouvrir(l),
      onAccepter: demande
          ? () => _repondre(l, accepter: true)
          : avis
          ? () => _repondreAvis(l)
          : null,
      onRefuser: demande ? () => _repondre(l, accepter: false) : null,
      libelleAccepter: avis ? 'Répondre' : 'Accepter',
    );
  }

  Widget _section(BuildContext context, String titre) {
    final c = TablCouleurs.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceL - 4,
        TablTokens.espaceL,
        TablTokens.espaceL - 4,
        TablTokens.espaceXs,
      ),
      child: Text(
        titre.toUpperCase(),
        style: c.legende.copyWith(
          fontSize: 11,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
          color: c.texte.withValues(alpha: 0.45),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final demandes = [
      for (final d in _demandes ?? const <LigneNotification>[])
        if (!_repondues.contains(d.acteur.id)) d,
    ];
    final nouvelles = [
      for (final l in _autres)
        if (l.nouvelle) l,
    ];
    final avant = [
      for (final l in _autres)
        if (!l.nouvelle) l,
    ];
    final charge = _demandes != null;
    return Scaffold(
      backgroundColor: c.fond,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TablTokens.espaceM,
                TablTokens.espaceS,
                TablTokens.espaceM,
                0,
              ),
              child: Row(
                children: [
                  TablBoutonRetour(onPresse: () => Navigator.of(context).pop()),
                  const SizedBox(width: TablTokens.espaceS),
                  Text(
                    'Notifications',
                    style: c.titreAffichage.copyWith(fontSize: 26),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: c.primaire,
                onRefresh: recharger,
                child: ListView(
                  padding: EdgeInsets.only(
                    bottom:
                        MediaQuery.paddingOf(context).bottom +
                        TablTokens.espaceXl,
                  ),
                  children: [
                    if (_erreur && !charge)
                      const _Vide(texte: messageErreurGenerique)
                    else if (!charge)
                      Padding(
                        padding: EdgeInsets.all(TablTokens.espaceXl),
                        child: Center(
                          child: CircularProgressIndicator(color: c.primaire),
                        ),
                      )
                    else if (demandes.isEmpty && _autres.isEmpty)
                      const _Vide(
                        texte: 'Rien de neuf pour l\'instant.',
                        detail:
                            'Les j\'aime, les commentaires et les demandes '
                            'de suivi arriveront ici.',
                      )
                    else ...[
                      if (demandes.isNotEmpty) ...[
                        _section(
                          context,
                          demandes.every(
                                (d) => d.type == TypeNotification.demandeSuivi,
                              )
                              ? (demandes.length == 1
                                    ? 'Demande de suivi'
                                    : 'Demandes de suivi')
                              : demandes.length == 1
                              ? 'Une demande'
                              : 'Demandes',
                        ),
                        for (final d in demandes) _ligne(d),
                      ],
                      if (nouvelles.isNotEmpty) ...[
                        _section(context, 'Nouvelles'),
                        for (final l in nouvelles) _ligne(l),
                      ],
                      if (avant.isNotEmpty) ...[
                        _section(context, 'Plus tôt'),
                        for (final l in avant) _ligne(l),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide({required this.texte, this.detail});

  final String texte;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceXl,
        TablTokens.espaceXxl,
        TablTokens.espaceXl,
        0,
      ),
      child: Column(
        children: [
          Icon(Icons.notifications_none_rounded, size: 36, color: c.texteDoux),
          const SizedBox(height: TablTokens.espaceM),
          Text(
            texte,
            textAlign: TextAlign.center,
            style: c.titreAffichage.copyWith(fontSize: 21),
          ),
          if (detail != null) ...[
            const SizedBox(height: TablTokens.espaceS),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: c.legende.copyWith(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}
