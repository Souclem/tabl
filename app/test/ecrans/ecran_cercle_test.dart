import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'package:app/ecrans/ecran_cercle.dart';

/// Faux [AbonnementService] à état contrôlable : les demandes acceptées
/// ou refusées disparaissent réellement de [demandesRecues], comme le
/// ferait le vrai service — pour tester le rafraîchissement après action.
class _FauxAbonnementService implements AbonnementService {
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
  Future<void> suivre(String suiviId) async {
    suivisAppeles.add(suiviId);
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
}

void main() {
  testWidgets('affiche les demandes reçues avec Accepter/Refuser', (
    tester,
  ) async {
    final service = _FauxAbonnementService(
      demandes: const [DemandeAbonnement(suiveurId: 'u1', pseudo: 'martin')],
    );

    await tester.pumpWidget(
      MaterialApp(home: EcranCercle(abonnementService: service)),
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
      MaterialApp(home: EcranCercle(abonnementService: service)),
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
      MaterialApp(home: EcranCercle(abonnementService: service)),
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
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: EcranCercle(abonnementService: service)),
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
        MaterialApp(home: EcranCercle(abonnementService: service)),
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
        MaterialApp(home: EcranCercle(abonnementService: service)),
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
      MaterialApp(home: EcranCercle(abonnementService: service)),
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
}
