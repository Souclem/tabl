import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'config_supabase.dart';
import 'ecrans/ecran_connexion.dart';
import 'ecrans/ecran_onboarding.dart';
import 'ecrans/ecran_principal.dart';

Future<void> main() async {
  // Obligatoire avant tout appel asynchrone précédant `runApp`.
  WidgetsFlutterBinding.ensureInitialized();

  await TablBackend.demarrer(
    url: ConfigSupabase.url,
    clePubliable: ConfigSupabase.clePubliable,
  );

  runApp(const TablApp());
}

class TablApp extends StatelessWidget {
  const TablApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Les écrans ne connaissent que l'interface AuthService : rebrancher
    // l'authentification ailleurs ne toucherait que cette ligne.
    final authService = AuthServiceSupabase(TablBackend.client);
    final abonnementService = AbonnementServiceSupabase(TablBackend.client);
    final souvenirService = SouvenirServiceSupabase(TablBackend.client);
    final etatOnboarding = EtatOnboardingPreferences();

    return MaterialApp(
      title: 'Tabl',
      debugShowCheckedModeBanner: false,
      theme: TablTheme.sombre(),
      home: EcranDemarrage(
        authService: authService,
        abonnementService: abonnementService,
        souvenirService: souvenirService,
        etatOnboarding: etatOnboarding,
      ),
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
  });

  final AuthService authService;
  final AbonnementService abonnementService;
  final SouvenirService souvenirService;
  final EtatOnboarding etatOnboarding;

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
          return const Scaffold(
            backgroundColor: TablTokens.fond,
            body: SizedBox.shrink(),
          );
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
