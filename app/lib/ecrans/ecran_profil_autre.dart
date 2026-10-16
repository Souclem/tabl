import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'actions_publications.dart';

/// Le profil d'une autre personne, présenté comme le sien : en-tête,
/// puis ses publications en lignes compactes qui se déplient sur place.
///
/// Comme Instagram : un profil privé que je ne suis pas ne montre que
/// l'en-tête et "Suivre" ; ses publications restent cachées. Pour le
/// reste, la base ne renvoie que les publications que j'ai le droit de
/// voir (RLS, réglage "Qui peut voir ?" de chacune).
class EcranProfilAutre extends StatefulWidget {
  const EcranProfilAutre({
    super.key,
    required this.profilId,
    required this.pseudo,
    required this.abonnementService,
    required this.souvenirService,
  });

  final String profilId;

  /// Affiché tout de suite, avant que le profil soit chargé.
  final String pseudo;
  final AbonnementService abonnementService;
  final SouvenirService souvenirService;

  @override
  State<EcranProfilAutre> createState() => _EcranProfilAutreState();
}

class _EcranProfilAutreState extends State<EcranProfilAutre>
    with ActionsPublications<EcranProfilAutre> {
  ProfilVisite? _profil;
  bool _chargement = true;
  bool _erreur = false;
  bool _actionEnCours = false;

  @override
  SouvenirService get souvenirService => widget.souvenirService;

  @override
  AbonnementService get abonnementService => widget.abonnementService;

  @override
  void initState() {
    super.initState();
    recharger();
  }

  @override
  void recharger() => _charger();

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = false;
    });
    try {
      final profil = await widget.abonnementService.profil(widget.profilId);
      final publications = profil.publicationsVisibles
          ? await widget.souvenirService.souvenirsDe(widget.profilId)
          : const <SouvenirFeed>[];
      if (!mounted) return;
      setState(() {
        _profil = profil;
        souvenirs = publications;
        _chargement = false;
      });
    } catch (e) {
      debugPrint('EcranProfilAutre: $e');
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = true;
      });
    }
  }

  Future<void> _suivre(ProfilVisite profil) => _agir(() async {
    final statut = await widget.abonnementService.suivre(profil.id);
    if (!mounted) return;
    // Profil public : abonné tout de suite. Privé : une demande, que
    // l'autre accepte ou refuse.
    setState(() => _profil = profil.copierAvec(statut: statut));
    if (statut == StatutAbonnement.demandeEnvoyee) {
      afficherMessage(context, 'Demande envoyée à ${profil.pseudo}.');
    }
  });

  Future<void> _annulerDemande(ProfilVisite profil) => _agir(() async {
    await widget.abonnementService.arreterDeSuivre(profil.id);
    if (!mounted) return;
    setState(() => _profil = profil.copierAvec(statut: StatutAbonnement.aucun));
  });

  Future<void> _nePlusSuivre(ProfilVisite profil) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexteDialogue) => AlertDialog(
        title: Text('Ne plus suivre ${profil.pseudo} ?'),
        content: profil.estPrive
            ? const Text(
                'Son profil est privé : vous ne verrez plus ses moments, '
                'sauf en renvoyant une demande.',
              )
            : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexteDialogue).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexteDialogue).pop(true),
            child: const Text('Ne plus suivre'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    await _agir(() async {
      await widget.abonnementService.arreterDeSuivre(profil.id);
      if (!mounted) return;
      // Un profil privé cache maintenant ses publications.
      _charger();
    });
  }

  Future<void> _agir(Future<void> Function() action) async {
    setState(() => _actionEnCours = true);
    try {
      await action();
    } catch (e) {
      debugPrint('EcranProfilAutre: $e');
      if (mounted) afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => _actionEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profil = _profil;
    final publications = souvenirs;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              color: TablTokens.primaire,
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.only(bottom: TablTokens.espaceXxl),
                children: [
                  TablEnTeteProfil(
                    pseudo: profil?.pseudo ?? widget.pseudo,
                    photoUrl: profil?.photoUrl,
                    resumeMoments:
                        profil != null &&
                            profil.publicationsVisibles &&
                            publications != null
                        ? libelleNombreMoments(publications.length)
                        : null,
                    action: profil == null ? null : _boutonSuivi(profil),
                  ),
                  if (_chargement && profil == null)
                    const Padding(
                      padding: EdgeInsets.all(TablTokens.espaceXl),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: TablTokens.primaire,
                        ),
                      ),
                    )
                  else if (_erreur || profil == null)
                    const _Message(texte: messageErreurGenerique)
                  else if (!profil.publicationsVisibles)
                    _ProfilPrive(pseudo: profil.pseudo)
                  else if (publications == null || publications.isEmpty)
                    const _Message(texte: 'Aucun moment à afficher.')
                  else
                    for (final souvenir in publications)
                      publicationDepliable(
                        souvenir,
                        contexte: ContextePublication.profilAutre,
                      ),
                ],
              ),
            ),
            Positioned(
              top: TablTokens.espaceS,
              left: TablTokens.espaceM,
              child: TablBoutonRetour(
                onPresse: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boutonSuivi(ProfilVisite profil) {
    final enCours = _actionEnCours;
    switch (profil.statut) {
      case StatutAbonnement.aucun:
      case StatutAbonnement.demandeRecue:
        return FilledButton(
          onPressed: enCours ? null : () => _suivre(profil),
          style: FilledButton.styleFrom(
            backgroundColor: TablTokens.primaire,
            foregroundColor: TablTokens.texteSurPrimaire,
          ),
          child: const Text('Suivre'),
        );
      case StatutAbonnement.demandeEnvoyee:
        return OutlinedButton(
          onPressed: enCours ? null : () => _annulerDemande(profil),
          child: const Text('Demande envoyée'),
        );
      case StatutAbonnement.abonne:
        return OutlinedButton(
          onPressed: enCours ? null : () => _nePlusSuivre(profil),
          child: const Text('Abonné'),
        );
    }
  }
}

/// À la place des publications d'un profil privé que je ne suis pas.
class _ProfilPrive extends StatelessWidget {
  const _ProfilPrive({required this.pseudo});

  final String pseudo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TablTokens.espaceXl),
      child: Column(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 32,
            color: TablTokens.texteDoux,
          ),
          const SizedBox(height: TablTokens.espaceM),
          const Text('Ce profil est privé', style: TablTokens.sousTitre),
          const SizedBox(height: TablTokens.espaceXs),
          Text(
            'Suivez $pseudo pour voir ses moments.',
            textAlign: TextAlign.center,
            style: TablTokens.corps.copyWith(color: TablTokens.texteDoux),
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
