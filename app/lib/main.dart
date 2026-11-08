import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'config_mapbox.dart';
import 'config_supabase.dart';
import 'ecrans/ecran_connexion.dart';
import 'ecrans/ecran_onboarding.dart';
import 'ecrans/ecran_principal.dart';

Future<void> main() async {
  // Obligatoire avant tout appel asynchrone précédant `runApp`.
  WidgetsFlutterBinding.ensureInitialized();

  if (ConfigMapbox.token.isEmpty) {
    debugPrint(
      'Token Mapbox absent : lancer avec --dart-define-from-file=.env '
      '(la carte restera vide).',
    );
  }
  MapboxOptions.setAccessToken(ConfigMapbox.token);

  await TablBackend.demarrer(
    url: ConfigSupabase.url,
    clePubliable: ConfigSupabase.clePubliable,
  );

  // Lue avant le premier écran : l'Explorer s'ouvre directement dans la
  // bonne apparence ; chaque changement est retenu sur l'appareil.
  final preferenceApparence = PreferenceApparencePreferences();
  final apparence = ValueNotifier(await preferenceApparence.lire());
  apparence.addListener(() => preferenceApparence.ecrire(apparence.value));

  runApp(TablApp(apparence: apparence));
}

class TablApp extends StatelessWidget {
  const TablApp({super.key, this.apparence});

  /// Clair ou sombre (voir [TablApparence]) ; `null` : sombre.
  final ValueNotifier<Apparence>? apparence;

  @override
  Widget build(BuildContext context) {
    // Les écrans ne connaissent que l'interface AuthService : rebrancher
    // l'authentification ailleurs ne toucherait que cette ligne.
    final authService = AuthServiceSupabase(TablBackend.client);
    final abonnementService = AbonnementServiceSupabase(TablBackend.client);
    final souvenirService = SouvenirServiceSupabase(TablBackend.client);
    final etatOnboarding = EtatOnboardingPreferences();
    // Contrairement à carteService/tableService (défaut paresseux à
    // l'intérieur d'EcranPrincipal, sans risque car Explorer/le tap
    // "Publier" ne s'exécutent jamais pendant les tests qui construisent
    // EcranPrincipal sans lui) : EcranFeed, qui a besoin de ce service,
    // est construit eagerly — un défaut paresseux là-bas serait déclenché
    // dès le premier build, y compris dans des tests sans Supabase
    // initialisé. Construit ici, au seul endroit où Supabase est déjà
    // garanti initialisé (après `TablBackend.demarrer` dans `main`).
    final instantService = InstantServiceSupabase(TablBackend.client);
    // Même raison : la cloche du Feed en a besoin dès son premier build.
    final notificationService = NotificationServiceSupabase(TablBackend.client);

    final reglage = apparence;

    MaterialApp application(Apparence choix) => MaterialApp(
      title: 'Tabl',
      debugShowCheckedModeBanner: false,
      theme: TablTheme.clair(),
      darkTheme: TablTheme.sombre(),
      themeMode: TablTheme.mode(choix),
      builder: (context, ecran) {
        if (reglage == null || ecran == null) return ecran ?? const SizedBox();
        return TablApparence(reglage: reglage, child: ecran);
      },
      home: EcranDemarrage(
        authService: authService,
        abonnementService: abonnementService,
        souvenirService: souvenirService,
        etatOnboarding: etatOnboarding,
        instantService: instantService,
        notificationService: notificationService,
      ),
    );

    if (reglage == null) return application(Apparence.sombre);
    // Le thème suit le réglage Apparence : un changement ne rebâtit que le
    // MaterialApp (le navigateur et ses écrans gardent leur état), et les
    // couleurs fondent d'un thème à l'autre.
    return ValueListenableBuilder<Apparence>(
      valueListenable: reglage,
      builder: (context, choix, _) => application(choix),
    );
  }
}

/// Choisit l'écran initial : le parcours de présentation s'il n'a jamais
/// été vu (FR-001, FR-008), sinon directement l'accueil connecté si une
/// session valide a été restaurée au démarrage, sinon l'écran de
/// connexion.
class EcranDemarrage extends StatefulWidget {
  const EcranDemarrage({
    super.key,
    required this.authService,
    required this.abonnementService,
    required this.souvenirService,
    required this.etatOnboarding,
    this.instantService,
    this.notificationService,
  });

  final AuthService authService;
  final AbonnementService abonnementService;
  final SouvenirService souvenirService;
  final EtatOnboarding etatOnboarding;

  /// `null` par défaut pour ne pas casser les tests qui construisent cet
  /// écran sans lui (aucun n'a besoin des Instants) — `TablApp` en
  /// fournit toujours un vrai dans l'app réelle (voir son commentaire).
  final InstantService? instantService;

  /// Même principe que [instantService].
  final NotificationService? notificationService;

  @override
  State<EcranDemarrage> createState() => _EcranDemarrageState();
}

class _EcranDemarrageState extends State<EcranDemarrage> {
  // Calculé une seule fois, à la création de l'état : si ce widget était
  // reconstruit pour une autre raison (l'app n'a aujourd'hui rien qui le
  // déclenche, mais rien ne l'empêche demain), un nouvel appel à
  // `_etat()` dans `build` relancerait la vérification de session — et
  // au passage un éventuel `signOut` — à chaque reconstruction.
  late final Future<(bool, Utilisateur?)> _futurEtat = _etat();

  /// (parcours déjà vu, utilisateur déjà connecté ou non).
  Future<(bool, Utilisateur?)> _etat() async {
    final dejaVu = await widget.etatOnboarding.aDejaVuOnboarding();
    if (!dejaVu) return (false, null);
    final utilisateur = await widget.authService.utilisateurConnecte();
    return (true, utilisateur);
  }

  @override
  Widget build(BuildContext context) {
    final authService = widget.authService;
    final abonnementService = widget.abonnementService;
    final souvenirService = widget.souvenirService;
    final etatOnboarding = widget.etatOnboarding;

    return FutureBuilder<(bool, Utilisateur?)>(
      future: _futurEtat,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: SizedBox.shrink());
        }

        // Une erreur inattendue au démarrage ne doit jamais se traduire
        // par un écran bloqué en silence : on retombe sur la connexion.
        if (snapshot.hasError) {
          return EcranConnexion(
            authService: authService,
            abonnementService: abonnementService,
            souvenirService: souvenirService,
          );
        }

        final (dejaVu, utilisateur) = snapshot.data!;
        if (!dejaVu) {
          return EcranOnboarding(
            authService: authService,
            abonnementService: abonnementService,
            souvenirService: souvenirService,
            etatOnboarding: etatOnboarding,
          );
        }
        if (utilisateur != null) {
          return EcranPrincipal(
            authService: authService,
            abonnementService: abonnementService,
            souvenirService: souvenirService,
            utilisateur: utilisateur,
            instantService: widget.instantService,
            notificationService: widget.notificationService,
          );
        }
        return EcranConnexion(
          authService: authService,
          abonnementService: abonnementService,
          souvenirService: souvenirService,
        );
      },
    );
  }
}
