import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Écran "Votre cercle" : chercher quelqu'un par pseudo, demander à le
/// suivre, répondre aux demandes reçues.
///
/// Volontairement minimal — pas de suggestions "amis en commun" ni
/// d'invitation par lien pour l'instant (voir la maquette Claude Design
/// pour la version complète visée, ajoutée plus tard).
class EcranCercle extends StatefulWidget {
  const EcranCercle({super.key, required this.abonnementService});

  final AbonnementService abonnementService;

  @override
  State<EcranCercle> createState() => _EcranCercleState();
}

class _EcranCercleState extends State<EcranCercle> {
  final _recherche = TextEditingController();

  List<DemandeAbonnement> _demandes = [];
  List<ProfilPublic> _resultats = [];
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
    _debounceRecherche?.cancel();
    _debounceRecherche = Timer(
      const Duration(milliseconds: 350),
      () => _rechercher(requete),
    );
  }

  Future<void> _chargerDemandes() async {
    setState(() => _chargementDemandes = true);
    try {
      final demandes = await widget.abonnementService.demandesRecues();
      if (!mounted) return;
      setState(() => _demandes = demandes);
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

  Future<void> _suivre(ProfilPublic profil) => _agir(profil.id, () async {
    await widget.abonnementService.suivre(profil.id);
    _remplacerResultat(profil.id, StatutAbonnement.demandeEnvoyee);
  });

  Future<void> _arreterDeSuivre(ProfilPublic profil) =>
      _agir(profil.id, () async {
        await widget.abonnementService.arreterDeSuivre(profil.id);
        _remplacerResultat(profil.id, StatutAbonnement.aucun);
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
                  Text('Votre cercle', style: TablTokens.titre),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(TablTokens.espaceL),
              child: TablChampTexte(
                libelle: 'Rechercher',
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
                        onRefuser: () => _refuser(demande),
                      ),
                    const SizedBox(height: TablTokens.espaceL),
                  ],
                  for (final profil in _resultats)
                    _LigneProfil(
                      profil: profil,
                      enCours: _idsEnCours.contains(profil.id),
                      onSuivre: () => _suivre(profil),
                      onArreterDeSuivre: () => _arreterDeSuivre(profil),
                    ),
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
    required this.onAccepter,
    required this.onRefuser,
  });

  final DemandeAbonnement demande;
  final bool enCours;
  final VoidCallback onAccepter;
  final VoidCallback onRefuser;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceS),
      child: Row(
        children: [
          Expanded(
            child: Text(demande.pseudo, style: TablTokens.corps),
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

class _LigneProfil extends StatelessWidget {
  const _LigneProfil({
    required this.profil,
    required this.enCours,
    required this.onSuivre,
    required this.onArreterDeSuivre,
  });

  final ProfilPublic profil;
  final bool enCours;
  final VoidCallback onSuivre;
  final VoidCallback onArreterDeSuivre;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceS),
      child: Row(
        children: [
          Expanded(child: Text(profil.pseudo, style: TablTokens.corps)),
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
