import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'package:app/ecrans/ecran_abonnes.dart';
import 'package:app/ecrans/ecran_profil_autre.dart';

/// Faux [AbonnementService] à état contrôlable : les demandes acceptées
/// ou refusées disparaissent réellement de [demandesRecues], comme le
/// ferait le vrai service — pour tester le rafraîchissement après action.
class _FauxAbonnementService implements AbonnementService {
  @override
  Future<CompteursProfil> compteurs(String profilId) =>
      throw UnimplementedError();

  @override
  Future<String> definirPhotoProfil(Uint8List photo) =>
      throw UnimplementedError();
  @override
  Future<ProfilVisite> profil(String id) async => ProfilVisite(
    id: id,
    pseudo: 'martin',
    estPrive: true,
    statut: StatutAbonnement.aucun,
  );

  List<ProfilPublic> abonnes = const [];
  List<ProfilPublic> abonnements = const [];

  @override
  Future<({List<ProfilPublic> abonnes, List<ProfilPublic> abonnements})>
  abonnesEtAbonnements() async =>
      (abonnes: abonnes, abonnements: abonnements);

  @override
  Future<Set<String>> mesAbonnesIds() async => {};

  @override
  Future<bool> monProfilEstPrive() async => true;

  @override
  Future<void> definirProfilPrive(bool prive) async {}

  _FauxAbonnementService({
    this._resultatsRecherche = const [],
    List<DemandeAbonnement> demandes = const [],
    this.erreurRecherche = false,
  }) : _demandes = List.of(demandes);

  final List<ProfilPublic> _resultatsRecherche;
  List<DemandeAbonnement> _demandes;
  final bool erreurRecherche;

  final List<String> suivisAppeles = [];
  final List<String> arretsAppeles = [];

  @override
  Future<List<ProfilPublic>> rechercher(String requete) async {
    if (erreurRecherche) throw Exception('erreur réseau');
    return _resultatsRecherche;
  }

  @override
  Future<StatutAbonnement> suivre(String suiviId) async {
    suivisAppeles.add(suiviId);
    return StatutAbonnement.demandeEnvoyee;
  }

  @override
  Future<void> arreterDeSuivre(String suiviId) async {
    arretsAppeles.add(suiviId);
  }

  @override
  Future<List<DemandeAbonnement>> demandesRecues() async => List.of(_demandes);

  @override
  Future<void> accepterDemande(String suiveurId) async {
    _demandes = _demandes.where((d) => d.suiveurId != suiveurId).toList();
  }

  @override
  Future<void> refuserDemande(String suiveurId) async {
    _demandes = _demandes.where((d) => d.suiveurId != suiveurId).toList();
  }

  @override
  Future<int> nombreDemandesEnAttente() async => _demandes.length;

  @override
  Future<List<ProfilPublic>> mesRelations() async => [];
}

class _FauxSouvenirService implements SouvenirService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  testWidgets('taper sur un nom ouvre son profil', (tester) async {
    final service = _FauxAbonnementService(
      demandes: const [DemandeAbonnement(suiveurId: 'u1', pseudo: 'martin')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EcranAbonnes(
          abonnementService: service,
          souvenirService: _FauxSouvenirService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('martin'));
    await tester.pumpAndSettle();

    expect(find.byType(EcranProfilAutre), findsOneWidget);
    expect(find.text('Ce profil est privé'), findsOneWidget);
  });

  testWidgets('affiche les demandes reçues avec Accepter/Refuser', (
    tester,
  ) async {
    final service = _FauxAbonnementService(
      demandes: const [DemandeAbonnement(suiveurId: 'u1', pseudo: 'martin')],
    );

    await tester.pumpWidget(
      MaterialApp(home: EcranAbonnes(abonnementService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Demandes'), findsOneWidget);
    expect(find.text('martin'), findsOneWidget);
    expect(find.text('Accepter'), findsOneWidget);
    expect(find.text('Refuser'), findsOneWidget);
  });

  testWidgets('accepter une demande la retire de la liste', (tester) async {
    final service = _FauxAbonnementService(
      demandes: const [DemandeAbonnement(suiveurId: 'u1', pseudo: 'martin')],
    );

    await tester.pumpWidget(
      MaterialApp(home: EcranAbonnes(abonnementService: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accepter'));
    await tester.pumpAndSettle();

    expect(find.text('martin'), findsNothing);
    expect(find.text('Demandes'), findsNothing);
  });

  testWidgets('refuser une demande la retire de la liste', (tester) async {
    final service = _FauxAbonnementService(
      demandes: const [DemandeAbonnement(suiveurId: 'u1', pseudo: 'martin')],
    );

    await tester.pumpWidget(
      MaterialApp(home: EcranAbonnes(abonnementService: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Refuser'));
    await tester.pumpAndSettle();

    expect(find.text('martin'), findsNothing);
  });

  testWidgets(
    'recherche : affiche les résultats avec le bon bouton selon le statut',
    (tester) async {
      final service = _FauxAbonnementService(
        resultatsRecherche: const [
          ProfilPublic(
            id: 'a',
            pseudo: 'camille',
            statut: StatutAbonnement.aucun,
          ),
          ProfilPublic(
            id: 'b',
            pseudo: 'louis',
            statut: StatutAbonnement.demandeEnvoyee,
          ),
          ProfilPublic(
            id: 'c',
            pseudo: 'emma',
            statut: StatutAbonnement.abonne,
          ),
          // Me suit, mais je ne la suis pas.
          ProfilPublic(
            id: 'd',
            pseudo: 'julia',
            statut: StatutAbonnement.aucun,
            meSuit: true,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: EcranAbonnes(abonnementService: service)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'cam');
      // Le debounce de recherche attend une courte pause dans la
      // frappe : pumpAndSettle seul ne voit pas passer un Timer brut,
      // il faut avancer explicitement au-delà de son délai.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('camille'), findsOneWidget);
      expect(find.text('louis'), findsOneWidget);
      expect(find.text('emma'), findsOneWidget);
      expect(find.text('Suivre'), findsOneWidget);
      expect(find.text('Suivre en retour'), findsOneWidget);
      expect(find.text('Demande envoyée'), findsOneWidget);
      expect(find.text('Abonné'), findsOneWidget);
    },
  );

  testWidgets(
    'taper sur "Suivre" appelle le service et met à jour le libellé',
    (tester) async {
      final service = _FauxAbonnementService(
        resultatsRecherche: const [
          ProfilPublic(
            id: 'a',
            pseudo: 'camille',
            statut: StatutAbonnement.aucun,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: EcranAbonnes(abonnementService: service)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'cam');
      // Le debounce de recherche attend une courte pause dans la
      // frappe : pumpAndSettle seul ne voit pas passer un Timer brut,
      // il faut avancer explicitement au-delà de son délai.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Suivre'));
      await tester.pumpAndSettle();

      expect(service.suivisAppeles, ['a']);
      expect(find.text('Demande envoyée'), findsOneWidget);
      expect(find.text('Suivre'), findsNothing);
    },
  );

  testWidgets(
    'taper sur "Demande envoyée" annule la demande et repasse à "Suivre"',
    (tester) async {
      final service = _FauxAbonnementService(
        resultatsRecherche: const [
          ProfilPublic(
            id: 'a',
            pseudo: 'camille',
            statut: StatutAbonnement.demandeEnvoyee,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: EcranAbonnes(abonnementService: service)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'cam');
      // Le debounce de recherche attend une courte pause dans la
      // frappe : pumpAndSettle seul ne voit pas passer un Timer brut,
      // il faut avancer explicitement au-delà de son délai.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Demande envoyée'));
      await tester.pumpAndSettle();

      expect(service.arretsAppeles, ['a']);
      expect(find.text('Suivre'), findsOneWidget);
    },
  );

  testWidgets('erreur de recherche → message générique affiché', (
    tester,
  ) async {
    final service = _FauxAbonnementService(erreurRecherche: true);

    await tester.pumpWidget(
      MaterialApp(home: EcranAbonnes(abonnementService: service)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'cam');
    // Le debounce de recherche attend une courte pause dans la
    // frappe : pumpAndSettle seul ne voit pas passer un Timer brut,
    // il faut avancer explicitement au-delà de son délai.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text(messageErreurGenerique), findsOneWidget);
  });

  testWidgets('onglets Abonnés / Abonnements, "Suivre en retour"', (
    tester,
  ) async {
    final service = _FauxAbonnementService()
      ..abonnes = const [
        ProfilPublic(id: 'a', pseudo: 'emma', statut: StatutAbonnement.aucun),
        ProfilPublic(id: 'b', pseudo: 'lucas', statut: StatutAbonnement.abonne),
      ]
      ..abonnements = const [
        ProfilPublic(id: 'c', pseudo: 'thomas', statut: StatutAbonnement.abonne),
      ];
    await tester.pumpWidget(
      MaterialApp(home: EcranAbonnes(abonnementService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Abonnés · 2'), findsOneWidget);
    expect(find.text('emma'), findsOneWidget);
    // Un seul "Suivre en retour" : lucas est déjà suivi.
    expect(find.text('Suivre en retour'), findsOneWidget);
    expect(find.text('thomas'), findsNothing);

    await tester.tap(find.text('Abonnements · 1'));
    await tester.pumpAndSettle();

    expect(find.text('thomas'), findsOneWidget);
    expect(find.text('emma'), findsNothing);
  });
}
