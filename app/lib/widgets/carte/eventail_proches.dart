import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../avatar.dart';
import '../boutons.dart';

const _fondCarte = Color(0xFF121318);
const _hauteurCarte = 156.0;
const _largeurMaxCarte = 168.0;
const _recouvrement = 12.0;
const _inclinaison = 0.05;
const _affaissement = 4.0;

/// Un proche, en carte dans l'éventail : tous ses textes sont déjà prêts.
class CarteEventail {
  const CarteEventail({
    required this.pseudo,
    required this.photoUrl,
    required this.fois,
    required this.derniereVisite,
    this.ressenti,
    this.onPresse,
  });

  final String pseudo;
  final String? photoUrl;

  /// "1 fois", "3 fois".
  final String fois;

  /// "Aujourd'hui", "Hier", "Il y a 2 mois".
  final String derniereVisite;

  /// Son ressenti de la dernière visite ("😍") ; `null` : pas de ressenti.
  final String? ressenti;

  /// Ouvre son profil ; `null` : pas touchable.
  final VoidCallback? onPresse;
}

/// La carte « +N » qui remplace les proches suivants.
class AutresEventail {
  const AutresEventail({
    required this.texte,
    this.nombreux = false,
    this.onPresse,
  });

  /// "+4", "+10".
  final String texte;

  /// Plus de dix autres : la carte se dore.
  final bool nombreux;

  /// Ouvre la liste « Qui y est allé » ; `null` : pas touchable.
  final VoidCallback? onPresse;
}

/// Les proches qui y sont allés, en cartes déployées en éventail : elles se
/// chevauchent un peu, penchent vers l'extérieur et suivent un léger arc.
/// La carte « +N », s'il y en a une, ferme l'éventail.
class TablEventail extends StatelessWidget {
  const TablEventail({super.key, required this.cartes, this.autres});

  final List<CarteEventail> cartes;
  final AutresEventail? autres;

  @override
  Widget build(BuildContext context) {
    final total = cartes.length + (autres == null ? 0 : 1);
    if (total == 0) return const SizedBox.shrink();
    final milieu = (total - 1) / 2;
    final ecartMax = milieu * milieu * _affaissement;
    return LayoutBuilder(
      builder: (context, contraintes) {
        final largeurCarte = total == 1
            ? contraintes.maxWidth.clamp(0, _largeurMaxCarte).toDouble()
            : ((contraintes.maxWidth + _recouvrement * (total - 1)) / total)
                  .clamp(0, _largeurMaxCarte)
                  .toDouble();
        final etendue =
            largeurCarte * total - _recouvrement * (total - 1).toDouble();
        final gauche = (contraintes.maxWidth - etendue) / 2;
        final enfants = [
          for (final c in cartes) _CarteProche(carte: c),
          if (autres != null) _CarteAutres(autres: autres!),
        ];
        return SizedBox(
          height: _hauteurCarte + ecartMax + 14,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < total; i++)
                Positioned(
                  left: gauche + i * (largeurCarte - _recouvrement),
                  top: 8 + (i - milieu) * (i - milieu) * _affaissement,
                  width: largeurCarte,
                  height: _hauteurCarte,
                  child: Transform.rotate(
                    angle: (i - milieu) * _inclinaison,
                    alignment: Alignment.bottomCenter,
                    child: enfants[i],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FondCarte extends StatelessWidget {
  const _FondCarte({
    required this.child,
    this.doree = false,
    this.libelle,
    this.onPresse,
  });

  final Widget child;
  final bool doree;
  final String? libelle;
  final VoidCallback? onPresse;

  @override
  Widget build(BuildContext context) {
    final carte = Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: doree
            ? Color.alphaBlend(
                TablTokens.primaire.withValues(alpha: 0.14),
                _fondCarte,
              )
            : _fondCarte,
        borderRadius: BorderRadius.circular(TablTokens.arrondiM),
        border: Border.all(
          color: doree
              ? TablTokens.primaire.withValues(alpha: 0.55)
              : TablTokens.texte.withValues(alpha: 0.1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    return Semantics(
      button: onPresse != null,
      label: libelle,
      excludeSemantics: libelle != null,
      child: onPresse == null
          ? carte
          : GestureDetector(onTap: onPresse, child: carte),
    );
  }
}

class _CarteProche extends StatelessWidget {
  const _CarteProche({required this.carte});

  final CarteEventail carte;

  @override
  Widget build(BuildContext context) {
    return _FondCarte(
      libelle: '${carte.pseudo}, ${carte.fois}, ${carte.derniereVisite}',
      onPresse: carte.onPresse,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              TablAvatar(
                pseudo: carte.pseudo,
                photoUrl: carte.photoUrl,
                rayon: 24,
              ),
              if (carte.ressenti != null)
                Positioned(
                  right: -8,
                  bottom: -6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: _fondCarte,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: TablTokens.texte.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      carte.ressenti!,
                      style: const TextStyle(fontSize: 14, height: 1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            carte.pseudo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TablTokens.titreAffichage.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            carte.fois,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TablTokens.legende.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: TablTokens.primaire,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            carte.derniereVisite,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TablTokens.legende.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _CarteAutres extends StatelessWidget {
  const _CarteAutres({required this.autres});

  final AutresEventail autres;

  @override
  Widget build(BuildContext context) {
    return _FondCarte(
      doree: autres.nombreux,
      libelle: '${autres.texte}, qui y est allé',
      onPresse: autres.onPresse,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            autres.texte,
            maxLines: 1,
            style: TablTokens.titreAffichage.copyWith(
              fontSize: 30,
              height: 1,
              color: autres.nombreux ? TablTokens.primaire : TablTokens.texte,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Qui y est allé',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TablTokens.legende.copyWith(fontSize: 11.5),
          ),
          if (autres.onPresse != null) ...[
            const SizedBox(height: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: TablTokens.texteDoux,
            ),
          ],
        ],
      ),
    );
  }
}

/// Les gestes sous l'éventail : le gros bouton « On y va ? » et
/// « Itinéraire ». Un geste sans callback n'est pas montré (pas de Table,
/// pas de lien d'itinéraire) ; sans aucun, la barre disparaît.
class TablBarreOnYVa extends StatelessWidget {
  const TablBarreOnYVa({super.key, this.onYVa, this.onItineraire});

  /// Choisir une Table et lui proposer le restaurant.
  final VoidCallback? onYVa;

  /// Ouvre l'application de plans.
  final VoidCallback? onItineraire;

  @override
  Widget build(BuildContext context) {
    if (onYVa == null && onItineraire == null) return const SizedBox.shrink();
    return Row(
      children: [
        if (onYVa != null)
          Expanded(
            flex: 3,
            child: TablBouton(libelle: 'On y va ?', onPresse: onYVa),
          ),
        if (onYVa != null && onItineraire != null) const SizedBox(width: 8),
        if (onItineraire != null)
          Expanded(
            flex: 2,
            child: SizedBox(
              height: TablTokens.hauteurControle,
              child: OutlinedButton.icon(
                onPressed: onItineraire,
                icon: const Icon(Icons.directions_rounded, size: 18),
                label: const Text('Itinéraire'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: TablTokens.texte,
                  side: BorderSide(
                    color: TablTokens.primaire.withValues(alpha: 0.45),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      TablTokens.arrondiBouton,
                    ),
                  ),
                  textStyle: TablTokens.libelleBouton,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
