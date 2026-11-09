import 'package:app/services/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> laisserFinir() => Future<void>.delayed(Duration.zero);

  test('démarrer ouvre la caméra et la déclare prête', () async {
    final camera = FausseCamera();
    expect(camera.etat.value, EtatCamera.eteinte);

    await camera.demarrer();

    expect(camera.etat.value, EtatCamera.prete);
    expect(camera.ouvertures, 1);
    await camera.fermer();
  });

  test('démarrer deux fois n\'ouvre qu\'une fois', () async {
    final camera = FausseCamera();
    await Future.wait([camera.demarrer(), camera.demarrer()]);

    expect(camera.ouvertures, 1);
    await camera.fermer();
  });

  test('fermer libère la caméra', () async {
    final camera = FausseCamera();
    await camera.demarrer();
    await camera.fermer();

    expect(camera.etat.value, EtatCamera.eteinte);
    expect(camera.ouverte, isFalse);
    expect(camera.fermetures, 1);
  });

  test('un refus d\'autorisation est affiché, sans photo possible', () async {
    final camera = FausseCamera(etatAtteint: EtatCamera.refusee);
    await camera.demarrer();

    expect(camera.etat.value, EtatCamera.refusee);
    expect(await camera.prendrePhoto(), isNull);
    await camera.fermer();
  });

  test('prendre une photo rend les octets et l\'heure de la prise', () async {
    final prise = DateTime(2026, 11, 8, 12, 30);
    final camera = FausseCamera(maintenant: () => prise);
    await camera.demarrer();

    final photo = await camera.prendrePhoto();

    expect(photo, isNotNull);
    expect(photo!.octets, camera.octetsPhoto);
    expect(photo.priseLe, prise);
    expect(camera.photosPrises, hasLength(1));
    await camera.fermer();
  });

  test('pas de photo tant que la caméra n\'est pas prête', () async {
    final camera = FausseCamera();

    expect(await camera.prendrePhoto(), isNull);
    expect(camera.photosPrises, isEmpty);
  });

  test('le flash choisi est appliqué, et gardé à la réouverture', () async {
    final camera = FausseCamera();
    await camera.demarrer();

    await camera.definirFlash(ModeFlash.active);
    expect(camera.flash, ModeFlash.active);
    expect(camera.flashsAppliques.last, ModeFlash.active);

    camera.surCycleDeVie(AppLifecycleState.inactive);
    camera.surCycleDeVie(AppLifecycleState.resumed);
    await laisserFinir();
    await laisserFinir();

    expect(camera.flashsAppliques.last, ModeFlash.active);
    await camera.fermer();
  });

  group('cycle de vie', () {
    test('libérée à inactive, relancée à la reprise', () async {
      final camera = FausseCamera();
      await camera.demarrer();

      camera.surCycleDeVie(AppLifecycleState.inactive);
      await laisserFinir();
      await laisserFinir();
      expect(camera.etat.value, EtatCamera.eteinte);
      expect(camera.ouverte, isFalse);

      camera.surCycleDeVie(AppLifecycleState.resumed);
      await laisserFinir();
      await laisserFinir();
      expect(camera.etat.value, EtatCamera.prete);
      expect(camera.ouverte, isTrue);
      expect(camera.ouvertures, 2);
      await camera.fermer();
    });

    testWidgets('suit le vrai cycle de vie de l\'app', (tester) async {
      final camera = FausseCamera();
      await camera.demarrer();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(camera.etat.value, EtatCamera.eteinte);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(camera.etat.value, EtatCamera.prete);

      await camera.fermer();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(camera.etat.value, EtatCamera.eteinte);
    });

    test('inactive puis reprise aussitôt, pendant l\'ouverture : une seule '
        'caméra ouverte à la fin', () async {
      final camera = FausseCamera(
        delaiOuverture: const Duration(milliseconds: 20),
      );
      final ouverture = camera.demarrer();

      camera.surCycleDeVie(AppLifecycleState.inactive);
      camera.surCycleDeVie(AppLifecycleState.resumed);
      await ouverture;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(camera.etat.value, EtatCamera.prete);
      expect(camera.ouverte, isTrue);
      expect(camera.ouvertures - camera.fermetures, 1);
      await camera.fermer();
    });

    test('fermée par l\'écran : la reprise ne la relance pas', () async {
      final camera = FausseCamera();
      await camera.demarrer();
      camera.surCycleDeVie(AppLifecycleState.inactive);
      await camera.fermer();

      camera.surCycleDeVie(AppLifecycleState.resumed);
      await laisserFinir();
      await laisserFinir();

      expect(camera.etat.value, EtatCamera.eteinte);
      expect(camera.ouvertures, 1);
    });

    test('un refus n\'est pas rouvert à la reprise', () async {
      final camera = FausseCamera(etatAtteint: EtatCamera.refusee);
      await camera.demarrer();

      camera.surCycleDeVie(AppLifecycleState.inactive);
      camera.surCycleDeVie(AppLifecycleState.resumed);
      await laisserFinir();
      await laisserFinir();

      expect(camera.etat.value, EtatCamera.refusee);
      expect(camera.ouvertures, 1);
      await camera.fermer();
    });

    test('une caméra jamais démarrée ignore le cycle de vie', () async {
      final camera = FausseCamera();

      camera.surCycleDeVie(AppLifecycleState.inactive);
      camera.surCycleDeVie(AppLifecycleState.resumed);
      await laisserFinir();

      expect(camera.ouvertures, 0);
    });
  });
}
