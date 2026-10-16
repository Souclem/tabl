import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

import 'package:app/ecrans/ecran_explorer.dart';

RestaurantMarqueur _resto({
  required String id,
  required String nom,
  String ville = 'Paris',
  int procheDirectCompte = 2,
  bool aDeLaRecurrence = false,
  bool dejaGardeParMoi = false,
  int? reseauEtenduCompte,
}) {
  return RestaurantMarqueur(
    id: id,
    nom: nom,
    ville: ville,
    quartier: 'Centre',
    latitude: 48.85 + procheDirectCompte * 0.01,
    longitude: 2.35 + procheDirectCompte * 0.01,
    taille: tailleMarqueurDepuisCompte(procheDirectCompte),
    procheDirectCompte: procheDirectCompte,
    procheDirectResume: 'Emma connaît cette adresse',
    aDeLaRecurrence: aDeLaRecurrence,
    dejaVisiteParMoi: false,
    dejaGardeParMoi: dejaGardeParMoi,
    reseauEtenduCompte: reseauEtenduCompte,
  );
}

class _FauxCarteService implements CarteService {
  _FauxCarteService({
    this.restaurantsParVille = const {},
    this.agregats = const [],
  });

  final Map<String, List<RestaurantMarqueur>> restaurantsParVille;
  final List<AgregatVille> agregats;

  final List<ModeCarte> appelsMode = [];
  final List<String> appelsBasculerGarder = [];

  @override
  Future<List<AgregatVille>> agregatsVilles({
    required ModeCarte mode,
    required PorteeSociale portee,
    required PeriodeCarte periode,
  }) async => agregats;

  @override
  Future<List<RestaurantMarqueur>> restaurantsPourVille({
    required String ville,
    required ModeCarte mode,
    required PorteeSociale portee,
    required PeriodeCarte periode,
    String? amiSelectionneId,
  }) async {
    appelsMode.add(mode);
    return restaurantsParVille[ville] ?? const [];
  }

  @override
  Future<void> basculerGarder(String restaurantId, {required bool garder}) async {
    appelsBasculerGarder.add(restaurantId);
  }
}

class _FauxAbonnementService implements AbonnementService {
  @override
  Future<List<ProfilPublic>> rechercher(String requete) async => [];

  @override
  Future<void> suivre(String suiviId) => throw UnimplementedError();

  @override
  Future<void> arreterDeSuivre(String suiviId) => throw UnimplementedError();

  @override
  Future<List<DemandeAbonnement>> demandesRecues() async => [];

  @override
  Future<void> accepterDemande(String suiveurId) => throw UnimplementedError();

  @override
  Future<void> refuserDemande(String suiveurId) => throw UnimplementedError();

  @override
  Future<int> nombreDemandesEnAttente() async => 0;

  @override
  Future<List<ProfilPublic>> mesAmis() async => [
    const ProfilPublic(id: 'emma', pseudo: 'Emma', statut: StatutAbonnement.abonne),
  ];
}

class _FauxRaccourcisVillesService implements RaccourcisVillesService {
  _FauxRaccourcisVillesService([List<String> villes = const ['Paris']])
      : villes = List.of(villes);

  final List<String> villes;

  @override
  Future<List<String>> mesVilles() async => villes;

  @override
  Future<void> ajouterVille(String ville) async => villes.add(ville);

  @override
  Future<void> retirerVille(String ville) async => villes.remove(ville);
}

class _FauxEntitlementService implements EntitlementService {
  _FauxEntitlementService({this.premium = false});
  final bool premium;

  @override
  Future<bool> aReseauEtendu() async => premium;
}

Widget _envelopper(Widget enfant) => MaterialApp(home: enfant);

void main() {
  group('EcranExplorer', () {
    testWidgets('affiche les restaurants de la ville active', (tester) async {
      final carteService = _FauxCarteService(
        restaurantsParVille: {
          'Paris': [_resto(id: '1', nom: 'Septime')],
        },
        agregats: const [AgregatVille(ville: 'Paris', latitude: 48.85, longitude: 2.35, nombreRestaurants: 1)],
      );

      await tester.pumpWidget(
        _envelopper(
          EcranExplorer(
            carteService: carteService,
            abonnementService: _FauxAbonnementService(),
            raccourcisVillesService: _FauxRaccourcisVillesService(),
            entitlementService: _FauxEntitlementService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PARIS'), findsOneWidget);
      expect(carteService.appelsMode, contains(ModeCarte.leCercle));
    });

    testWidgets('zone vide sans restaurant affiche un message honnête', (tester) async {
      await tester.pumpWidget(
        _envelopper(
          EcranExplorer(
            carteService: _FauxCarteService(),
            abonnementService: _FauxAbonnementService(),
            raccourcisVillesService: _FauxRaccourcisVillesService(),
            entitlementService: _FauxEntitlementService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Peu d\'adresses'), findsOneWidget);
    });

    testWidgets('tap sur un restaurant ouvre sa preview', (tester) async {
      final carteService = _FauxCarteService(
        restaurantsParVille: {
          'Paris': [_resto(id: '1', nom: 'Septime')],
        },
        agregats: const [AgregatVille(ville: 'Paris', latitude: 48.85, longitude: 2.35, nombreRestaurants: 1)],
      );

      await tester.pumpWidget(
        _envelopper(
          EcranExplorer(
            carteService: carteService,
            abonnementService: _FauxAbonnementService(),
            raccourcisVillesService: _FauxRaccourcisVillesService(),
            entitlementService: _FauxEntitlementService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel(RegExp('Septime')));
      await tester.pumpAndSettle();

      expect(find.text('Septime'), findsWidgets);
      expect(find.text('Garder'), findsOneWidget);
    });

    testWidgets('Garder appelle basculerGarder sur le service', (tester) async {
      final carteService = _FauxCarteService(
        restaurantsParVille: {
          'Paris': [_resto(id: '1', nom: 'Septime')],
        },
        agregats: const [AgregatVille(ville: 'Paris', latitude: 48.85, longitude: 2.35, nombreRestaurants: 1)],
      );

      await tester.pumpWidget(
        _envelopper(
          EcranExplorer(
            carteService: carteService,
            abonnementService: _FauxAbonnementService(),
            raccourcisVillesService: _FauxRaccourcisVillesService(),
            entitlementService: _FauxEntitlementService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(RegExp('Septime')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Garder'));
      await tester.pumpAndSettle();

      expect(carteService.appelsBasculerGarder, ['1']);
    });

    testWidgets('changer de mode recharge avec le bon mode', (tester) async {
      final carteService = _FauxCarteService(
        restaurantsParVille: {
          'Paris': [_resto(id: '1', nom: 'Septime')],
        },
        agregats: const [AgregatVille(ville: 'Paris', latitude: 48.85, longitude: 2.35, nombreRestaurants: 1)],
      );

      await tester.pumpWidget(
        _envelopper(
          EcranExplorer(
            carteService: carteService,
            abonnementService: _FauxAbonnementService(),
            raccourcisVillesService: _FauxRaccourcisVillesService(),
            entitlementService: _FauxEntitlementService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ma carte'));
      await tester.pumpAndSettle();

      expect(carteService.appelsMode, contains(ModeCarte.maCarte));
    });

    testWidgets('une seule bottom sheet à la fois (tap rapide sur période)', (tester) async {
      await tester.pumpWidget(
        _envelopper(
          EcranExplorer(
            carteService: _FauxCarteService(
              restaurantsParVille: {
                'Paris': [_resto(id: '1', nom: 'Septime')],
              },
              agregats: const [AgregatVille(ville: 'Paris', latitude: 48.85, longitude: 2.35, nombreRestaurants: 1)],
            ),
            abonnementService: _FauxAbonnementService(),
            raccourcisVillesService: _FauxRaccourcisVillesService(),
            entitlementService: _FauxEntitlementService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.textContaining('▾'));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('Période'), findsOneWidget);
    });

    testWidgets('réseau étendu verrouillé pour un compte gratuit', (tester) async {
      await tester.pumpWidget(
        _envelopper(
          EcranExplorer(
            carteService: _FauxCarteService(),
            abonnementService: _FauxAbonnementService(),
            raccourcisVillesService: _FauxRaccourcisVillesService(),
            entitlementService: _FauxEntitlementService(premium: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Filtres'));
      await tester.pumpAndSettle();

      expect(find.text('Réseau étendu 🔒'), findsOneWidget);
      expect(find.text('Les deux'), findsNothing);
    });
  });
}
