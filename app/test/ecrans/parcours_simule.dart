import 'dart:convert';

import 'package:app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

final pngTest = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

const comptoirTest = LieuRestaurant(
  fsqPlaceId: 'fsq-comptoir',
  nom: 'Le Comptoir',
  ville: 'Liège',
  latitude: 50.6327,
  longitude: 5.5799,
);

class FauxSouvenirService implements SouvenirService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FauxAbonnementService implements AbonnementService {
  @override
  Future<bool> monProfilEstPrive() async => false;

  @override
  Future<Set<String>> mesAbonnesIds() async => {};

  @override
  Future<List<ProfilPublic>> mesRelations() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FausseRechercheLieu implements RechercheLieuService {
  @override
  Future<List<LieuRestaurant>> lieuxProches({
    required double latitude,
    required double longitude,
    double rayonM = 250,
    int limite = 8,
  }) async => [comptoirTest];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class PositionFixe implements PositionService {
  @override
  Future<Coordonnees?> positionActuelle() async =>
      (latitude: 50.63, longitude: 5.57);
}

/// Laisse la vraie entrée-sortie (fichiers du brouillon) se terminer.
Future<void> attendre(WidgetTester tester, {int tours = 20}) async {
  for (var i = 0; i < tours; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Attend, par petits tours, que [condition] soit vraie : l'envoi réel
/// (fichiers) prend un temps qu'on ne peut pas fixer.
Future<void> attendreJusque(
  WidgetTester tester,
  bool Function() condition,
) async {
  for (var i = 0; i < 400 && !condition(); i++) {
    await attendre(tester, tours: 5);
  }
}

/// Attend qu'un élément apparaisse à l'écran.
Future<void> attendreAffichage(WidgetTester tester, Finder cherche) =>
    attendreJusque(tester, () => cherche.evaluate().isNotEmpty);
