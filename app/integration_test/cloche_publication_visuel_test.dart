import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/ecrans/ecran_cloche.dart';
import 'package:app/ecrans/ecran_principal.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

const _comptoir = LieuRestaurant(
  fsqPlaceId: 'fsq-comptoir',
  nom: 'Le Comptoir',
  ville: 'Liège',
  latitude: 50.6327,
  longitude: 5.5799,
);

class _FauxAuth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FauxAvis implements AvisService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FauxTables implements TableService {
  @override
  Future<List<ResumeTable>> mesTables() async => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FauxNotifications implements NotificationService {
  @override
  Future<({List<NotificationTabl> notifications, DateTime? vuesLe})>
  mesNotifications() async =>
      (notifications: <NotificationTabl>[], vuesLe: null);
  @override
  Future<void> marquerVues(DateTime moment) async {}
}

class _FauxSysteme implements NotificationsSysteme {
  @override
  Future<void> activer() async {}
  @override
  Stream<String> get touchees => const Stream.empty();
}

class _FauxAbonnements implements AbonnementService {
  @override
  Future<bool> monProfilEstPrive() async => false;
  @override
  Future<Set<String>> mesAbonnesIds() async => {};
  @override
  Future<List<ProfilPublic>> mesRelations() async => const [];
  @override
  Future<List<SuggestionAmi>> suggestions() async => const [];
  @override
  Future<int> nombreDemandesEnAttente() async => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FauxSouvenirs implements SouvenirService {
  var publie = false;

  @override
  Future<List<SouvenirFeed>> feed() async => publie
      ? [
          SouvenirFeed(
            id: 'nouveau',
            photoUrl: null,
            legende: 'Le meilleur moment de la semaine.',
            restaurantNom: 'Le Comptoir',
            ville: 'Liège',
            moment: 'soir',
            dateVisite: DateTime.now(),
            auteurPseudo: 'moi',
            nombreReactions: 0,
            jaiReagi: false,
            nombreCommentaires: 0,
            estAMoi: true,
            auteurId: 'moi',
          ),
        ]
      : [];
  @override
  Future<List<SouvenirFeed>> souvenirsDe(String auteurId) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FausseRecherche implements RechercheLieuService {
  @override
  Future<List<LieuRestaurant>> lieuxProches({
    required double latitude,
    required double longitude,
    double rayonM = 250,
    int limite = 8,
  }) async => [_comptoir];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _PositionFixe implements PositionService {
  @override
  Future<Coordonnees?> positionActuelle() async =>
      (latitude: 50.63, longitude: 5.57);
}

typedef _Essai =
    Future<ResultatEnvoi> Function(void Function(int, int)? surProgression);

class _FauxEnvois implements EnvoiPublications {
  _FauxEnvois(this.brouillons, this.souvenirs, this.essais);
  @override
  final BrouillonsLocaux brouillons;
  final _FauxSouvenirs souvenirs;
  final List<_Essai> essais;
  var appels = 0;
  var garder = 0;
  var attente = 0;
  Completer<ResultatEnvoi>? _courant;

  @override
  Future<ResultatEnvoi> envoyer(
    String brouillonId, {
    void Function(int envoyees, int total)? surProgression,
  }) async {
    final essai = essais[appels < essais.length ? appels : essais.length - 1];
    appels++;
    final c = _courant = Completer<ResultatEnvoi>();
    unawaited(
      essai(surProgression).then(
        (r) {
          if (!c.isCompleted) c.complete(r);
        },
        onError: (Object e, StackTrace s) {
          if (!c.isCompleted) c.completeError(e, s);
        },
      ),
    );
    final r = await c.future;
    if (r.estPublie) souvenirs.publie = true;
    return r;
  }

  @override
  Future<bool> garderEnBrouillon(String brouillonId) async {
    garder++;
    final c = _courant;
    if (c != null && !c.isCompleted) {
      c.complete(const ResultatEnvoi(StatutEnvoi.annule));
    }
    return true;
  }

  @override
  Future<bool> mettreEnAttente(String brouillonId) async {
    attente++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> _avancer(WidgetTester t, {int ms = 1000}) async {
  for (var i = 0; i < ms / 100; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _capture(WidgetTester t, String nom) async {
  await t.pump(const Duration(milliseconds: 100));
  debugPrint('CAPTURE:$nom');
  await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
}

Future<void> _tapper(WidgetTester t, Finder f, {int ms = 500}) async {
  await t.tap(f);
  await _avancer(t, ms: ms);
}

Future<_FauxEnvois> _jusquaLaCloche(WidgetTester t, List<_Essai> essais) async {
  final racine = Directory.systemTemp.createTempSync('cloche_visuel');
  final maintenant = DateTime.now();
  final brouillons = BrouillonsLocaux(racine, maintenant: () => maintenant);
  final souvenirs = _FauxSouvenirs();
  final envois = _FauxEnvois(brouillons, souvenirs, essais);
  await t.pumpWidget(
    MaterialApp(
      home: EcranPrincipal(
        authService: _FauxAuth(),
        abonnementService: _FauxAbonnements(),
        souvenirService: souvenirs,
        utilisateur: const Utilisateur(
          id: 'moi',
          email: 'moi@exemple.com',
          pseudo: 'moi',
        ),
        notificationService: _FauxNotifications(),
        notificationsSysteme: _FauxSysteme(),
        avisService: _FauxAvis(),
        tableService: _FauxTables(),
        rechercheLieuService: _FausseRecherche(),
        positionService: _PositionFixe(),
        camera: FausseCamera(octetsPhoto: _png, maintenant: () => maintenant),
        envois: envois,
      ),
    ),
  );
  await _avancer(t);
  await _tapper(t, find.bySemanticsLabel('Publier un moment'), ms: 1500);
  await _tapper(t, find.byType(DeclencheurCamera));
  await _tapper(t, find.text('Continuer · 1'), ms: 1500);
  await _tapper(t, find.text('🤩'), ms: 300);
  await _tapper(t, find.text('Publier'), ms: 300);
  return envois;
}

Future<ResultatEnvoi> _lent(
  void Function(int, int)? p, {
  required ResultatEnvoi fin,
  int secondes = 4,
}) async {
  p?.call(0, 1);
  await Future<void>.delayed(Duration(seconds: secondes ~/ 2));
  p?.call(1, 1);
  await Future<void>.delayed(Duration(seconds: secondes - secondes ~/ 2));
  return fin;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('publication réussie : cloche puis Fil', (t) async {
    final handle = t.ensureSemantics();
    await _jusquaLaCloche(t, [
      (p) =>
          _lent(p, fin: const ResultatEnvoi(StatutEnvoi.publie), secondes: 5),
    ]);
    await _avancer(t, ms: 1500);
    expect(find.byType(EcranCloche), findsOneWidget);
    await _capture(t, 'cloche_1_progression');
    await _avancer(t, ms: 6000);
    await _avancer(t, ms: 2000);
    expect(find.byType(EcranCloche), findsNothing);
    expect(find.textContaining('Le meilleur moment'), findsOneWidget);
    await _capture(t, 'cloche_5_fil_arrivee');
    handle.dispose();
  });

  testWidgets('hors ligne : Envoyer dès que possible', (t) async {
    final handle = t.ensureSemantics();
    final envois = await _jusquaLaCloche(t, [
      (p) async => throw const SocketException('pas de réseau'),
    ]);
    await _avancer(t, ms: 1500);
    expect(find.text('Envoyer dès que possible'), findsOneWidget);
    expect(find.text('Garder en brouillon'), findsOneWidget);
    await _capture(t, 'cloche_2_hors_ligne');
    await _tapper(t, find.text('Envoyer dès que possible'), ms: 3000);
    expect(envois.attente, 1);
    expect(find.byType(EcranCloche), findsNothing);
    handle.dispose();
  });

  testWidgets('échec puis Réessayer', (t) async {
    final handle = t.ensureSemantics();
    final envois = await _jusquaLaCloche(t, [
      (p) async => const ResultatEnvoi(StatutEnvoi.echec, erreur: 'boom'),
      (p) =>
          _lent(p, fin: const ResultatEnvoi(StatutEnvoi.publie), secondes: 2),
    ]);
    await _avancer(t, ms: 1500);
    expect(find.text('Réessayer'), findsOneWidget);
    await _capture(t, 'cloche_3_echec');
    await _tapper(t, find.text('Réessayer'), ms: 500);
    await _avancer(t, ms: 6000);
    expect(envois.appels, 2);
    expect(find.byType(EcranCloche), findsNothing);
    expect(find.textContaining('Le meilleur moment'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('annulation pendant l\'envoi', (t) async {
    final handle = t.ensureSemantics();
    final envois = await _jusquaLaCloche(t, [
      (p) =>
          _lent(p, fin: const ResultatEnvoi(StatutEnvoi.publie), secondes: 30),
    ]);
    await _avancer(t, ms: 1000);
    expect(find.text('Annuler'), findsOneWidget);
    await _tapper(t, find.text('Annuler'), ms: 3000);
    expect(envois.garder, 1);
    expect(find.byType(EcranCloche), findsNothing);
    await _capture(t, 'cloche_4_apres_annulation');
    handle.dispose();
  });

  testWidgets('passage en arrière-plan puis retour', (t) async {
    final handle = t.ensureSemantics();
    await _jusquaLaCloche(t, [
      (p) =>
          _lent(p, fin: const ResultatEnvoi(StatutEnvoi.publie), secondes: 8),
    ]);
    await _avancer(t, ms: 1000);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _avancer(t, ms: 500);
    expect(find.byType(EcranCloche), findsOneWidget);
    await _capture(t, 'cloche_6_retour_arriere_plan');
    await _avancer(t, ms: 9000);
    expect(find.byType(EcranCloche), findsNothing);
    handle.dispose();
  });
}
