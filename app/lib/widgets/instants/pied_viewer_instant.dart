import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Pied du viewer (megaprompt Bloc 2, règle 93, 38) : le restaurant
/// reste toujours présent, avec une action pour rejoindre l'expérience
/// complète.
class TablPiedViewerInstant extends StatelessWidget {
  const TablPiedViewerInstant({
    super.key,
    required this.restaurantNom,
    required this.ville,
    required this.onVoirExperience,
  });

  final String restaurantNom;
  final String ville;
  final VoidCallback onVoirExperience;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0x99000000), Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TablTokens.espaceM,
            TablTokens.espaceL,
            TablTokens.espaceM,
            TablTokens.espaceM,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      restaurantNom,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      ville,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onVoirExperience,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text(
                  "Voir l'expérience",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
