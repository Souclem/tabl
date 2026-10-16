import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:app/services/services.dart';

import 'package:app/ecrans/ecran_viewer_instants.dart';

class _FauxInstantService implements InstantService {
  _FauxInstantService(this.parInstants);

  final Map<String, List<InstantAffichable>> parInstants;
  final List<String> appelsVu = [];
  final List<String> appelsSupprimer = [];

  @override
  Future<List<InstantAffichable>> instantsDe(String experienceId) async =>
      parInstants[experienceId] ?? const [];

  @override
  Future<void> marquerVu(String instantId) async {
    appelsVu.add(instantId);
  }

  @override
  Future<void> supprimer(String instantId) async {
    appelsSupprimer.add(instantId);
    for (final liste in parInstants.values) {
      liste.removeWhere((i) => i.id == instantId);
    }
  }

  @override
  Future<void> creer({
    required String experienceId,
    required TypeMediaInstant type,
    required dynamic media,
  }) => throw UnimplementedError();

  @override
  Future<Map<String, SignalInstants>> signaux(List<String> experienceIds) =>
      throw UnimplementedError();
}

InstantAffichable _instant(String id, {bool estMoi = false}) {
  return InstantAffichable(
    id: id,
    mediaUrl: 'https://exemple.test/$id.jpg',
    type: TypeMediaInstant.photo,
    creeLe: DateTime(2026, 9, 17),
    estMoi: estMoi,
  );
}

void main() {
  testWidgets('affiche la position 1/2 puis 2/2 après tap à droite', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      final service = _FauxInstantService({
        'exp-1': [_instant('i1'), _instant('i2')],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: EcranViewerInstants(
            instantService: service,
            contextes: const [
              ContexteInstant(
                experienceId: 'exp-1',
                auteurPseudo: 'Thomas',
                restaurantNom: 'Septime',
                ville: 'Paris',
              ),
            ],
            indexInitial: 0,
            onVoirExperience: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('Thomas'), findsOneWidget);
      expect(find.text('Septime · maintenant'), findsOneWidget);

      // Tap sur la moitié droite de l'écran → média suivant.
      await tester.tapAt(const Offset(700, 400));
      await tester.pumpAndSettle();

      expect(find.text('2 / 2'), findsOneWidget);
    });
  });

  testWidgets(
    'après le dernier média, sans expérience suivante : ferme le viewer',
    (tester) async {
      await mockNetworkImagesFor(() async {
        final service = _FauxInstantService({'exp-1': [_instant('i1')]});

        // Poussé sur une pile réelle (pour que Navigator.pop() ait un
        // écran en dessous, comme en vrai — même principe que
        // `_ouvrirEcranPublier` dans ecran_publier_test.dart).
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EcranViewerInstants(
                        instantService: service,
                        contextes: const [
                          ContexteInstant(
                            experienceId: 'exp-1',
                            auteurPseudo: 'Thomas',
                            restaurantNom: 'Septime',
                            ville: 'Paris',
                          ),
                        ],
                        indexInitial: 0,
                        onVoirExperience: (_) {},
                      ),
                    ),
                  ),
                  child: const Text('ouvrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('ouvrir'));
        await tester.pumpAndSettle();

        await tester.tapAt(const Offset(700, 400));
        await tester.pumpAndSettle();

        expect(find.byType(EcranViewerInstants), findsNothing);
      });
    },
  );

  testWidgets(
    "après le dernier média, avec une expérience suivante : propose \"Ensuite\" sans y aller automatiquement",
    (tester) async {
      await mockNetworkImagesFor(() async {
        final service = _FauxInstantService({
          'exp-1': [_instant('i1')],
          'exp-2': [_instant('i2')],
        });

        await tester.pumpWidget(
          MaterialApp(
            home: EcranViewerInstants(
              instantService: service,
              contextes: const [
                ContexteInstant(
                  experienceId: 'exp-1',
                  auteurPseudo: 'Thomas',
                  restaurantNom: 'Septime',
                  ville: 'Paris',
                ),
                ContexteInstant(
                  experienceId: 'exp-2',
                  auteurPseudo: 'Emma',
                  restaurantNom: 'Le Voltaire',
                  ville: 'Paris',
                ),
              ],
              indexInitial: 0,
              onVoirExperience: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tapAt(const Offset(700, 400));
        await tester.pumpAndSettle();

        // Toujours sur "Ensuite" : pas de bascule automatique.
        expect(find.text('Ensuite'), findsOneWidget);
        expect(find.text('Emma'), findsOneWidget);
        expect(find.text('Septime'), findsNothing);

        await tester.tap(find.text('Emma'));
        await tester.pumpAndSettle();

        expect(find.text('Emma'), findsWidgets);
        expect(find.text('Le Voltaire · maintenant'), findsOneWidget);
      });
    },
  );

  testWidgets('"Voir l\'expérience" appelle le callback avec le bon id', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      final service = _FauxInstantService({'exp-1': [_instant('i1')]});
      String? experienceOuverte;

      await tester.pumpWidget(
        MaterialApp(
          home: EcranViewerInstants(
            instantService: service,
            contextes: const [
              ContexteInstant(
                experienceId: 'exp-1',
                auteurPseudo: 'Thomas',
                restaurantNom: 'Septime',
                ville: 'Paris',
              ),
            ],
            indexInitial: 0,
            onVoirExperience: (id) => experienceOuverte = id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Voir l'expérience"));
      expect(experienceOuverte, 'exp-1');
    });
  });

  testWidgets(
    'expérience sans Instant actif (expiré/supprimé) : message sobre, pas de crash',
    (tester) async {
      final service = _FauxInstantService({'exp-1': const []});

      await tester.pumpWidget(
        MaterialApp(
          home: EcranViewerInstants(
            instantService: service,
            contextes: const [
              ContexteInstant(
                experienceId: 'exp-1',
                auteurPseudo: 'Thomas',
                restaurantNom: 'Septime',
                ville: 'Paris',
              ),
            ],
            indexInitial: 0,
            onVoirExperience: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("Cette expérience n'est plus disponible."),
        findsOneWidget,
      );
    },
  );
}
