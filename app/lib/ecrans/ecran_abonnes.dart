import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_profil_autre.dart';

/// Écran "Abonnés" : répondre aux demandes reçues, voir ses abonnés et
/// ses abonnements (suivi asymétrique type Instagram), et trouver des
/// personnes par pseudo — la recherche remplace les listes tant qu'elle
/// n'est pas vide. Toucher une personne ouvre son profil.
///
/// Pas encore de suggestions ni d'invitation par lien.
class EcranAbonnes extends StatefulWidget {
  const EcranAbonnes({
    super.key,
    required this.abonnementService,
    required this.souvenirService,
    this.ongletAbonnes = true,
  });

  /// L'onglet ouvert à l'arrivée : abonnés (par défaut) ou abonnements.
  final bool ongletAbonnes;

  final AbonnementService abonnementService;

  /// Pour ouvrir le profil d'une personne de la liste.
  final SouvenirService souvenirService;

  @override
  State<EcranAbonnes> createState() => _EcranAbonnesState();
}

class _EcranAbonnesState extends State<EcranAbonnes> {
  final _recherche = TextEditingController();

  List<DemandeAbonnement> _demandes = [];
  List<ProfilPublic> _resultats = [];
  List<ProfilPublic> _abonnes = [];
  List<ProfilPublic> _abonnements = [];
  late bool _ongletAbonnes = widget.ongletAbonnes;
  bool _chargementDemandes = true;

  /// Les listes ont été chargées au moins une fois : les rechargements
  /// suivants (après chaque geste) se font sans sablier.
  bool _charge = false;

  /// Une recherche part ou attend sa réponse : pas encore de « personne
  /// de ce nom ».
  bool _rechercheEnCours = false;
  final Set<String> _idsEnCours = {};
  Timer? _debounceRecherche;

  @override
  void initState() {
    super.initState();
    _chargerDemandes();
  }

  @override
  void dispose() {
    _debounceRecherche?.cancel();
    _recherche.dispose();
    super.dispose();
  }

  /// Attend une courte pause dans la frappe avant de chercher : sinon
  /// chaque caractère tapé déclenche un aller-retour réseau séparé.
  void _rechercherAvecDebounce(String requete) {
    // Bascule tout de suite entre listes et résultats de recherche.
    setState(() => _rechercheEnCours = requete.trim().isNotEmpty);
    _debounceRecherche?.cancel();
    if (requete.trim().isEmpty) return;
    _debounceRecherche = Timer(
      const Duration(milliseconds: 350),
      () => _rechercher(requete),
    );
  }

  Future<void> _chargerDemandes() async {
    setState(() => _chargementDemandes = true);
    try {
      final resultats = await Future.wait<Object>([
        widget.abonnementService.demandesRecues(),
        widget.abonnementService.abonnesEtAbonnements(),
      ]);
      if (!mounted) return;
      final listes =
          resultats[1]
              as ({List<ProfilPublic> abonnes, List<ProfilPublic> abonnements});
      setState(() {
        _demandes = resultats[0] as List<DemandeAbonnement>;
        _abonnes = listes.abonnes;
        _abonnements = listes.abonnements;
        _charge = true;
      });
    } catch (_) {
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => _chargementDemandes = false);
    }
  }

  Future<void> _rechercher(String requete) async {
    try {
      final resultats = await widget.abonnementService.rechercher(requete);
      if (!mounted || _recherche.text != requete) return;
      setState(() {
        _resultats = resultats;
        _rechercheEnCours = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _rechercheEnCours = false);
      afficherMessage(context, messageErreurGenerique);
    }
  }

  /// Le profil d'une personne ; au retour, les listes sont rechargées
  /// (un abonnement a pu changer depuis son profil).
  Future<void> _ouvrirProfil(String id, String pseudo) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranProfilAutre(
          profilId: id,
          pseudo: pseudo,
          abonnementService: widget.abonnementService,
          souvenirService: widget.souvenirService,
        ),
      ),
    );
    if (!mounted) return;
    await _chargerDemandes();
  }

  Future<void> _suivre(ProfilPublic profil) => _agir(profil.id, () async {
    final statut = await widget.abonnementService.suivre(profil.id);
    _remplacerResultat(profil.id, statut);
    await _chargerDemandes();
  });

  Future<void> _arreterDeSuivre(ProfilPublic profil) =>
      _agir(profil.id, () async {
        await widget.abonnementService.arreterDeSuivre(profil.id);
        _remplacerResultat(profil.id, StatutAbonnement.aucun);
        await _chargerDemandes();
      });

  /// Retire un abonné : même opération que refuser sa demande.
  Future<void> _retirerAbonne(ProfilPublic profil) =>
      _agir(profil.id, () async {
        await widget.abonnementService.refuserDemande(profil.id);
        await _chargerDemandes();
      });

  Future<void> _accepter(DemandeAbonnement demande) =>
      _agir(demande.suiveurId, () async {
        await widget.abonnementService.accepterDemande(demande.suiveurId);
        await _chargerDemandes();
      });

  Future<void> _refuser(DemandeAbonnement demande) =>
      _agir(demande.suiveurId, () async {
        await widget.abonnementService.refuserDemande(demande.suiveurId);
        await _chargerDemandes();
      });

  Future<void> _agir(String id, Future<void> Function() action) async {
    setState(() => _idsEnCours.add(id));
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => _idsEnCours.remove(id));
    }
  }

  void _remplacerResultat(String id, StatutAbonnement statut) {
    setState(() {
      _resultats = _resultats
          .map((p) => p.id == id ? _avecStatut(p, statut) : p)
          .toList();
    });
  }

  ProfilPublic _avecStatut(ProfilPublic p, StatutAbonnement statut) =>
      p.copierAvec(statut: statut);

  @override
  Widget build(BuildContext context) {
    final enRecherche = _recherche.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: TablTokens.fond,
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
                    'Abonnés',
                    style: TablTokens.titreAffichage.copyWith(fontSize: 26),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TablTokens.espaceL - 4,
                TablTokens.espaceM,
                TablTokens.espaceL - 4,
                TablTokens.espaceS,
              ),
              child: TablBarreRecherche(
                controleur: _recherche,
                indication: 'Trouver des personnes',
                onChanged: _rechercherAvecDebounce,
              ),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  bottom:
                      MediaQuery.paddingOf(context).bottom +
                      TablTokens.espaceXl,
                ),
                children: enRecherche
                    ? _resultatsRecherche()
                    : _demandesEtRelations(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _resultatsRecherche() {
    if (_resultats.isEmpty) {
      return [
        if (_rechercheEnCours)
          const _Sablier()
        else
          const _Vide(
            icone: Icons.search_off_rounded,
            texte: 'Personne de ce nom.',
            detail: 'Vérifiez l\'orthographe du pseudo.',
          ),
      ];
    }
    return [
      for (final profil in _resultats)
        TablLignePersonne(
          pseudo: profil.pseudo,
          photoUrl: profil.photoUrl,
          precision: _precision(profil),
          onPresse: () => _ouvrirProfil(profil.id, profil.pseudo),
          actions: [?_boutonSuivi(profil)],
        ),
    ];
  }

  List<Widget> _demandesEtRelations() {
    if (!_charge) {
      return [if (_chargementDemandes) const _Sablier()];
    }
    final liste = _ongletAbonnes ? _abonnes : _abonnements;
    return [
      if (_demandes.isNotEmpty) ...[
        _Section(
          titre: _demandes.length == 1
              ? 'Demande'
              : 'Demandes · ${_demandes.length}',
        ),
        for (final demande in _demandes)
          TablLignePersonne(
            pseudo: demande.pseudo,
            photoUrl: demande.photoUrl,
            precision: 'Veut vous suivre',
            onPresse: () => _ouvrirProfil(demande.suiveurId, demande.pseudo),
            actions: [
              TablPetitBouton(
                libelle: 'Accepter',
                plein: true,
                onPresse: _idsEnCours.contains(demande.suiveurId)
                    ? null
                    : () => _accepter(demande),
              ),
              TablPetitBouton(
                libelle: 'Refuser',
                onPresse: _idsEnCours.contains(demande.suiveurId)
                    ? null
                    : () => _refuser(demande),
              ),
            ],
          ),
        const SizedBox(height: TablTokens.espaceM),
      ],
      TablOngletsTexte(
        libelles: [
          'Abonnés · ${_abonnes.length}',
          'Abonnements · ${_abonnements.length}',
        ],
        index: _ongletAbonnes ? 0 : 1,
        onChoisir: (i) => setState(() => _ongletAbonnes = i == 0),
      ),
      const SizedBox(height: TablTokens.espaceS),
      if (liste.isEmpty)
        _ongletAbonnes
            ? const _Vide(
                icone: Icons.people_outline_rounded,
                texte: 'Personne ne vous suit encore.',
                detail:
                    'Ceux qui vous suivent apparaîtront ici, avec de quoi '
                    'les suivre en retour.',
              )
            : const _Vide(
                icone: Icons.person_search_rounded,
                texte: 'Vous ne suivez personne.',
                detail:
                    'Cherchez un pseudo ci-dessus pour retrouver vos '
                    'proches.',
              )
      else if (_ongletAbonnes)
        for (final profil in liste)
          TablLignePersonne(
            pseudo: profil.pseudo,
            photoUrl: profil.photoUrl,
            precision: _precisionAbonne(profil),
            onPresse: () => _ouvrirProfil(profil.id, profil.pseudo),
            actions: [
              if (profil.statut == StatutAbonnement.aucun)
                TablPetitBouton(
                  libelle: 'Suivre en retour',
                  plein: true,
                  onPresse: _idsEnCours.contains(profil.id)
                      ? null
                      : () => _suivre(profil),
                ),
              IconButton(
                tooltip: 'Options',
                visualDensity: VisualDensity.compact,
                onPressed: _idsEnCours.contains(profil.id)
                    ? null
                    : () => _optionsAbonne(profil),
                icon: const Icon(
                  Icons.more_horiz_rounded,
                  size: 20,
                  color: TablTokens.texteDoux,
                ),
              ),
            ],
          )
      else
        for (final profil in liste)
          TablLignePersonne(
            pseudo: profil.pseudo,
            photoUrl: profil.photoUrl,
            precision: _precision(profil),
            onPresse: () => _ouvrirProfil(profil.id, profil.pseudo),
            actions: [?_boutonSuivi(profil)],
          ),
    ];
  }

  /// « Retirer » derrière « ⋯ » : un geste rare, qu'on ne fait pas par
  /// mégarde en parcourant la liste.
  void _optionsAbonne(ProfilPublic profil) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: TablTokens.surface,
      showDragHandle: true,
      builder: (contexteFeuille) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.person_remove_outlined,
                color: TablTokens.erreur,
              ),
              title: const Text(
                'Retirer de mes abonnés',
                style: TextStyle(color: TablTokens.erreur),
              ),
              subtitle: Text(
                '${profil.pseudo} ne verra plus vos moments réservés à '
                'vos abonnés. Aucune notification ne lui est envoyée.',
                style: TablTokens.legende,
              ),
              onTap: () {
                Navigator.of(contexteFeuille).pop();
                _retirerAbonne(profil);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Ce que la personne fait de son côté, en plus discret sous son nom.
  String? _precision(ProfilPublic profil) {
    if (profil.statut == StatutAbonnement.demandeRecue) {
      return 'Veut vous suivre';
    }
    return profil.meSuit ? 'Vous suit' : null;
  }

  /// Un abonné : il me suit déjà, par définition ; ce qui compte, c'est
  /// où j'en suis avec lui.
  String? _precisionAbonne(ProfilPublic profil) => switch (profil.statut) {
    StatutAbonnement.abonne => 'Vous vous suivez',
    StatutAbonnement.demandeEnvoyee => 'Demande envoyée',
    _ => null,
  };

  /// Suivre, ou où en est mon suivi ; rien si c'est elle qui m'a fait une
  /// demande (elle est dans « Demandes »).
  Widget? _boutonSuivi(ProfilPublic profil) {
    final enCours = _idsEnCours.contains(profil.id);
    return switch (profil.statut) {
      StatutAbonnement.aucun => TablPetitBouton(
        libelle: profil.meSuit ? 'Suivre en retour' : 'Suivre',
        plein: true,
        onPresse: enCours ? null : () => _suivre(profil),
      ),
      StatutAbonnement.demandeEnvoyee => TablPetitBouton(
        libelle: 'Demande envoyée',
        onPresse: enCours ? null : () => _arreterDeSuivre(profil),
      ),
      StatutAbonnement.abonne => TablPetitBouton(
        libelle: 'Abonné',
        onPresse: enCours ? null : () => _arreterDeSuivre(profil),
      ),
      StatutAbonnement.demandeRecue => null,
    };
  }
}

/// Titre de section, en petites capitales comme dans les notifications.
class _Section extends StatelessWidget {
  const _Section({required this.titre});

  final String titre;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceL - 4,
        TablTokens.espaceM,
        TablTokens.espaceL - 4,
        TablTokens.espaceXs,
      ),
      child: Text(
        titre.toUpperCase(),
        style: TablTokens.legende.copyWith(
          fontSize: 11,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
          color: TablTokens.texte.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _Sablier extends StatelessWidget {
  const _Sablier();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(TablTokens.espaceXl),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: TablTokens.primaire,
          ),
        ),
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide({required this.icone, required this.texte, this.detail});

  final IconData icone;
  final String texte;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceXl,
        TablTokens.espaceXl,
        TablTokens.espaceXl,
        0,
      ),
      child: Column(
        children: [
          Icon(icone, size: 34, color: TablTokens.texteDoux),
          const SizedBox(height: TablTokens.espaceM),
          Text(
            texte,
            textAlign: TextAlign.center,
            style: TablTokens.titreAffichage.copyWith(fontSize: 20),
          ),
          if (detail != null) ...[
            const SizedBox(height: TablTokens.espaceS),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: TablTokens.legende.copyWith(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}
