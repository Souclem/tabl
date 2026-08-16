import 'package:flutter/material.dart';
import 'package:tabl_core/tabl_core.dart';
import 'package:tabl_ui/tabl_ui.dart';

import 'config_supabase.dart';
import 'ecrans/ecran_connexion.dart';

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

    return MaterialApp(
      title: 'Tabl',
      debugShowCheckedModeBanner: false,
      theme: TablTheme.clair(),
      home: EcranConnexion(authService: authService),
    );
  }
}
