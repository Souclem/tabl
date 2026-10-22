import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'package:app/ecrans/ecran_carte.dart';

/// Faux service : applique quelques filtres comme le ferait la base, et
/// garde les recherches reçues pour vérifier que l'écran recharge.
class _FauxCarteService implements CarteService {
  _FauxCarteService(this.lieux);

  final List<LieuCarte> lieux;
  final List<FiltresCarte> recherches = [];
  final List<ZoneCarte> zones = [];

  @override
  Future<List<LieuCarte>> lieuxReseau(
    ZoneCarte zone,
    FiltresCarte filtres, {
    int limite = nombreMaxLieuxCarte,
  }) async {
    recherches.add(filtres);
    zones.add(zone);
    return [
      for (final l in lieux)
        if (l.amis > 0 &&
            (!filtres.coupsDeCoeur || l.coupsDeCoeur > 0) &&
            (!filtres.mesEnvies || l.estEnvie))
          l,
    ];
  }

  @override
  Future<String> idRestaurant(LieuCarte lieu) async => lieu.restaurantId!;

  @override
  Future<void> basculerEnvie(
    String restaurantId, {
    required bool envie,
  }) async {}
}

class _FauxAbonnementService implements AbonnementService {
  @override
  Future<({List<ProfilPublic> abonnes, List<ProfilPublic> abonnements})>
  abonnesEtAbonnements() async => (
    abonnes: <ProfilPublic>[],
    abonnements: const [
      ProfilPublic(id: 'emma', pseudo: 'Emma', statut: StatutAbonnement.abonne),
    ],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Un restaurant où Emma est allée (à Liège, sauf [latitude] et
/// [longitude] données).
LieuCarte _lieu(
  String nom, {
  bool coupDeCoeur = false,
  bool envie = false,
  double latitude = 50.64,
  double longitude = 5.57,
}) => LieuCarte(
  restaurantId: nom,
  nom: nom,
  ville: 'Liège',
  latitude: latitude,
  longitude: longitude,
  categories: const ['Brasserie'],
  estEnvie: envie,
  amis: 1,
  visites: 1,
  coupsDeCoeur: coupDeCoeur ? 1 : 0,
  amiPseudo: 'Emma',
);

Future<_FauxCarteService> _ouvrir(
  WidgetTester tester,
  List<LieuCarte> lieux,
) async {
  final service = _FauxCarteService(lieux);
  await tester.pumpWidget(
    MaterialApp(
      theme: TablTheme.sombre(),
      home: EcranCarte(
        carteService: service,
        abonnementService: _FauxAbonnementService(),
        afficherCarte: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

/// La rangée de filtres défile horizontalement : on amène la pastille à
/// l'écran avant de la toucher.
Future<void> _toucher(WidgetTester tester, String texte) async {
  await tester.ensureVisible(find.text(texte));
  await tester.pumpAndSettle();
  await tester.tap(find.text(texte));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('en-tête : titre, bascule Carte / Liste et filtres', (
    tester,
  ) async {
    await _ouvrir(tester, []);

    expect(find.text('Carte'), findsWidgets);
    expect(find.text('Liste'), findsOneWidget);
    expect(find.text('Une personne'), findsOneWidget);
    expect(find.text('Mes envies'), findsOneWidget);
    expect(find.text('Coups de cœur 😍'), findsOneWidget);
  });

  testWidgets('la liste montre les lieux du réseau, filtrés', (tester) async {
    await _ouvrir(tester, [
      _lieu('Le Campus', coupDeCoeur: true),
      _lieu('Bibo'),
      _lieu('Como en Casa', envie: true),
    ]);

    await tester.tap(find.text('Liste'));
    await tester.pumpAndSettle();
    expect(find.text('Le Campus'), findsOneWidget);
    expect(find.text('Bibo'), findsOneWidget);
    expect(find.text('Como en Casa'), findsOneWidget);
    expect(find.text('Emma y est allé'), findsNWidgets(3));

    await _toucher(tester, 'Coups de cœur 😍');
    expect(find.text('Le Campus'), findsOneWidget);
    expect(find.text('Bibo'), findsNothing);

    // "Effacer" remet tout.
    await _toucher(tester, 'Effacer (1)');
    expect(find.text('Bibo'), findsOneWidget);

    await _toucher(tester, 'Mes envies');
    expect(find.text('Como en Casa'), findsOneWidget);
    expect(find.text('Le Campus'), findsNothing);
  });

  testWidgets('tout est chargé d\'un coup ; la liste suit la zone visible', (
    tester,
  ) async {
    final service = await _ouvrir(tester, [
      _lieu('Bibo'),
      _lieu('Le Comptoir Paris', latitude: 48.86, longitude: 2.35),
    ]);

    // Le monde entier : les bulles de la carte comptent juste partout.
    expect(service.zones.single, same(ZoneCarte.monde));

    // La liste s'en tient à la zone visible (la Belgique au départ).
    await tester.tap(find.text('Liste'));
    await tester.pumpAndSettle();
    expect(find.text('Bibo'), findsOneWidget);
    expect(find.text('Le Comptoir Paris'), findsNothing);
  });

  testWidgets('filtre "une personne" : choix dans une feuille', (tester) async {
    final service = await _ouvrir(tester, [_lieu('Bibo')]);
    await tester.tap(find.text('Une personne'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emma'));
    await tester.pumpAndSettle();

    expect(find.text('Emma'), findsOneWidget);
    expect(find.text('Effacer (1)'), findsOneWidget);
    // Le filtre part à la base : nouvelle recherche avec la personne.
    expect(service.recherches.last.personneId, 'emma');
  });

  testWidgets('liste vide avec filtres : message dédié', (tester) async {
    await _ouvrir(tester, [_lieu('Bibo')]);
    await tester.tap(find.text('Liste'));
    await _toucher(tester, 'Coups de cœur 😍');

    expect(
      find.text('Aucun lieu de votre réseau ne correspond à ces filtres.'),
      findsOneWidget,
    );
  });
}
