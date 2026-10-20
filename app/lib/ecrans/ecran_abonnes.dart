import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_profil_autre.dart';

/// Écran "Abonnés" : répondre aux demandes reçues, voir ses abonnés et
/// ses abonnements (suivi asymétrique type Instagram), et trouver des
/// personnes par pseudo — la recherche remplace les deux listes tant
/// qu'elle n'est pas vide.
///
/// Pas encore de suggestions ni d'invitation par lien.
class EcranAbonnes extends StatefulWidget {
  const EcranAbonnes({
    super.key,
    required this.abonnementService,
    this.souvenirService,
    this.ongletAbonnes = true,
  });

  /// L'onglet ouvert à l'arrivée : abonnés (par défaut) ou abonnements.
  final bool ongletAbonnes;

  final AbonnementService abonnementService;

  /// Pour ouvrir le profil d'une personne de la liste ; `null` : les noms
  /// ne sont pas touchables.
  final SouvenirService? souvenirService;

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
    setState(() {});
    _debounceRecherche?.cancel();
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
      setState(() => _resultats = resultats);
    } catch (_) {
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    }
  }

  /// Le profil d'une personne ; au retour, les listes sont rechargées
  /// (un abonnement a pu changer depuis son profil).
  Future<void> _ouvrirProfil(String id, String pseudo) async {
    final souvenirs = widget.souvenirService;
    if (souvenirs == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranProfilAutre(
          profilId: id,
          pseudo: pseudo,
          abonnementService: widget.abonnementService,
          souvenirService: souvenirs,
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

  ProfilPublic _avecStatut(ProfilPublic p, StatutAbonnement statut) {
    return ProfilPublic(id: p.id, pseudo: p.pseudo, statut: statut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TablTokens.espaceL,
                TablTokens.espaceM,
                TablTokens.espaceL,
                0,
              ),
              child: Row(
                children: [
                  TablBoutonRetour(onPresse: () => Navigator.of(context).pop()),
                  const SizedBox(width: TablTokens.espaceM),
                  Text('Abonnés', style: TablTokens.titre),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(TablTokens.espaceL),
              child: TablChampTexte(
                libelle: 'Trouver des personnes',
                controleur: _recherche,
                indication: 'Un pseudo',
                iconePrefixe: Icons.search_rounded,
                onChanged: _rechercherAvecDebounce,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: TablTokens.espaceL,
                ),
                children: [
                  if (_chargementDemandes)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: TablTokens.espaceM,
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: TablTokens.primaire,
                          ),
                        ),
                      ),
                    ),
                  if (_demandes.isNotEmpty) ...[
                    Text('Demandes', style: TablTokens.sousTitre),
                    const SizedBox(height: TablTokens.espaceS),
                    for (final demande in _demandes)
                      _LigneDemande(
                        demande: demande,
                        enCours: _idsEnCours.contains(demande.suiveurId),
                        onAccepter: () => _accepter(demande),
                        onOuvrir: () =>
                            _ouvrirProfil(demande.suiveurId, demande.pseudo),
                        onRefuser: () => _refuser(demande),
                      ),
                    const SizedBox(height: TablTokens.espaceL),
                  ],
                  if (_recherche.text.trim().isNotEmpty)
                    for (final profil in _resultats)
                      _LigneProfil(
                        profil: profil,
                        enCours: _idsEnCours.contains(profil.id),
                        onSuivre: () => _suivre(profil),
                        onArreterDeSuivre: () => _arreterDeSuivre(profil),
                        onOuvrir: () => _ouvrirProfil(profil.id, profil.pseudo),
                      )
                  else ...[
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: true,
                          label: Text('Abonnés · ${_abonnes.length}'),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('Abonnements · ${_abonnements.length}'),
                        ),
                      ],
                      selected: {_ongletAbonnes},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) =>
                          setState(() => _ongletAbonnes = s.first),
                      style: SegmentedButton.styleFrom(
                        backgroundColor: TablTokens.surface,
                        selectedBackgroundColor: TablTokens.primaire,
                        foregroundColor: TablTokens.texte,
                        selectedForegroundColor: TablTokens.texteSurPrimaire,
                      ),
                    ),
                    const SizedBox(height: TablTokens.espaceS),
                    if (_ongletAbonnes)
                      for (final profil in _abonnes)
                        _LigneAbonne(
                          profil: profil,
                          enCours: _idsEnCours.contains(profil.id),
                          onSuivreEnRetour: () => _suivre(profil),
                          onRetirer: () => _retirerAbonne(profil),
                          onOuvrir: () =>
                              _ouvrirProfil(profil.id, profil.pseudo),
                        )
                    else
                      for (final profil in _abonnements)
                        _LigneProfil(
                          profil: profil,
                          enCours: _idsEnCours.contains(profil.id),
                          onSuivre: () => _suivre(profil),
                          onArreterDeSuivre: () => _arreterDeSuivre(profil),
                          onOuvrir: () =>
                              _ouvrirProfil(profil.id, profil.pseudo),
                        ),
                    if (!_chargementDemandes &&
                        (_ongletAbonnes ? _abonnes : _abonnements).isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: TablTokens.espaceL,
                        ),
                        child: Text(
                          _ongletAbonnes
                              ? 'Personne ne vous suit encore.'
                              : 'Vous ne suivez personne pour le moment.',
                          textAlign: TextAlign.center,
                          style: TablTokens.legende,
                        ),
                      ),
                  ],
                  const SizedBox(height: TablTokens.espaceL),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LigneDemande extends StatelessWidget {
  const _LigneDemande({
    required this.demande,
    required this.enCours,
    required this.onOuvrir,
    required this.onAccepter,
    required this.onRefuser,
  });

  final DemandeAbonnement demande;
  final bool enCours;

  /// Tap sur le nom : ouvre le profil.
  final VoidCallback onOuvrir;
  final VoidCallback onAccepter;
  final VoidCallback onRefuser;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceS),
      child: Row(
        children: [
          Expanded(
            child: _Nom(pseudo: demande.pseudo, onPresse: onOuvrir),
          ),
          TextButton(
            onPressed: enCours ? null : onRefuser,
            child: const Text('Refuser'),
          ),
          const SizedBox(width: TablTokens.espaceXs),
          FilledButton(
            onPressed: enCours ? null : onAccepter,
            style: FilledButton.styleFrom(
              backgroundColor: TablTokens.primaire,
              foregroundColor: TablTokens.texteSurPrimaire,
            ),
            child: const Text('Accepter'),
          ),
        ],
      ),
    );
  }
}

/// Un abonné : "Suivre en retour" si je ne le suis pas encore, et
/// "Retirer" pour qu'il ne me suive plus.
class _LigneAbonne extends StatelessWidget {
  const _LigneAbonne({
    required this.profil,
    required this.enCours,
    required this.onOuvrir,
    required this.onSuivreEnRetour,
    required this.onRetirer,
  });

  final ProfilPublic profil;
  final bool enCours;

  /// Tap sur le nom : ouvre le profil.
  final VoidCallback onOuvrir;
  final VoidCallback onSuivreEnRetour;
  final VoidCallback onRetirer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceS),
      child: Row(
        children: [
          Expanded(
            child: _Nom(pseudo: profil.pseudo, onPresse: onOuvrir),
          ),
          TextButton(
            onPressed: enCours ? null : onRetirer,
            child: const Text('Retirer'),
          ),
          if (profil.statut == StatutAbonnement.aucun) ...[
            const SizedBox(width: TablTokens.espaceXs),
            FilledButton(
              onPressed: enCours ? null : onSuivreEnRetour,
              style: FilledButton.styleFrom(
                backgroundColor: TablTokens.primaire,
                foregroundColor: TablTokens.texteSurPrimaire,
              ),
              child: const Text('Suivre en retour'),
            ),
          ],
        ],
      ),
    );
  }
}

class _LigneProfil extends StatelessWidget {
  const _LigneProfil({
    required this.profil,
    required this.enCours,
    required this.onOuvrir,
    required this.onSuivre,
    required this.onArreterDeSuivre,
  });

  final ProfilPublic profil;
  final bool enCours;

  /// Tap sur le nom : ouvre le profil.
  final VoidCallback onOuvrir;
  final VoidCallback onSuivre;
  final VoidCallback onArreterDeSuivre;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceS),
      child: Row(
        children: [
          Expanded(
            child: _Nom(pseudo: profil.pseudo, onPresse: onOuvrir),
          ),
          _bouton(),
        ],
      ),
    );
  }

  Widget _bouton() {
    switch (profil.statut) {
      case StatutAbonnement.aucun:
        return FilledButton(
          onPressed: enCours ? null : onSuivre,
          style: FilledButton.styleFrom(
            backgroundColor: TablTokens.primaire,
            foregroundColor: TablTokens.texteSurPrimaire,
          ),
          child: const Text('Suivre'),
        );
      case StatutAbonnement.demandeEnvoyee:
        return OutlinedButton(
          onPressed: enCours ? null : onArreterDeSuivre,
          child: const Text('Demande envoyée'),
        );
      case StatutAbonnement.abonne:
        return OutlinedButton(
          onPressed: enCours ? null : onArreterDeSuivre,
          child: const Text('Abonné'),
        );
      case StatutAbonnement.demandeRecue:
        return const Text(
          'Vous a demandé',
          style: TablTokens.legende,
        );
    }
  }
}

/// Le nom d'une personne dans une liste, touchable pour ouvrir son
/// profil.
class _Nom extends StatelessWidget {
  const _Nom({required this.pseudo, required this.onPresse});

  final String pseudo;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPresse,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceS),
        child: Text(pseudo, style: TablTokens.corps),
      ),
    );
  }
}
