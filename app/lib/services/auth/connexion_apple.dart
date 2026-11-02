import 'package:flutter/foundation.dart';

/// « Continuer avec Apple » n'est proposé que sur iPhone : c'est là que
/// la connexion Apple est native (voir `AuthServiceSupabase.connexionApple`).
/// Sur Android, elle passerait par le flux web d'Apple (Services ID, clé
/// secrète à renouveler tous les six mois), qui n'est pas mis en place.
bool get connexionAppleProposee => defaultTargetPlatform == TargetPlatform.iOS;
