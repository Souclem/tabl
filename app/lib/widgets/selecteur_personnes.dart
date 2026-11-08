import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'avatar.dart';

/// Une personne qu'on peut cocher dans [TablSelecteurPersonnes].
class PersonneSelectionnable {
  const PersonneSelectionnable({
    required this.id,
    required this.pseudo,
    this.photoUrl,
  });

  final String id;
  final String pseudo;
  final String? photoUrl;
}

/// « Qui était là ? » : les têtes des personnes en rangée qui défile ;
/// toucher une tête la coche (anneau doré et petite coche), la retoucher
/// la décoche. On reconnaît quelqu'un à son visage bien avant son pseudo.
class TablSelecteurPersonnes extends StatelessWidget {
  const TablSelecteurPersonnes({
    super.key,
    required this.personnes,
    required this.selection,
    required this.onBascule,
  });

  final List<PersonneSelectionnable> personnes;
  final Set<String> selection;
  final ValueChanged<String> onBascule;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: personnes.length,
        separatorBuilder: (_, _) => const SizedBox(width: TablTokens.espaceM),
        itemBuilder: (context, i) {
          final p = personnes[i];
          return _Tete(
            personne: p,
            cochee: selection.contains(p.id),
            onPresse: () => onBascule(p.id),
          );
        },
      ),
    );
  }
}

class _Tete extends StatelessWidget {
  const _Tete({
    required this.personne,
    required this.cochee,
    required this.onPresse,
  });

  final PersonneSelectionnable personne;
  final bool cochee;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    const duree = Duration(milliseconds: 220);
    final c = TablCouleurs.of(context);
    return Semantics(
      button: true,
      selected: cochee,
      label: personne.pseudo,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPresse,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 66,
          child: Column(
            children: [
              SizedBox(
                width: 62,
                height: 62,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: duree,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cochee ? c.primaire : c.bordure,
                          width: cochee ? 2 : 1,
                        ),
                      ),
                      child: AnimatedOpacity(
                        duration: duree,
                        opacity: cochee ? 1 : 0.75,
                        child: TablAvatar(
                          pseudo: personne.pseudo,
                          photoUrl: personne.photoUrl,
                          rayon: 26,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: AnimatedScale(
                        duration: duree,
                        curve: Curves.easeOutBack,
                        scale: cochee ? 1 : 0,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: c.primaire,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.fond, width: 2),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: c.texteSurPrimaire,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                personne.pseudo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: c.legende.copyWith(
                  fontSize: 12,
                  color: cochee ? c.primaire : c.texte,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
