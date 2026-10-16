import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'bouton_reaction.dart';
import 'instants/bouton_ajouter_instant.dart';
import 'instants/signal_instants_post.dart';

/// Où une publication est affichée — seul ce qui diffère d'un endroit à
/// l'autre en dépend, le corps du post (photo, lieu, légende,
/// impressions, J'aime/Commenter) reste identique partout.
enum ContextePublication {
  /// Feed : auteur visible (on y mélange plusieurs personnes), bouton
  /// "Enregistrer".
  feed,

  /// Son propre profil : pas d'auteur (c'est toujours soi), pas
  /// d'"Enregistrer" (on n'ajoute pas sa propre adresse à ses envies),
  /// mais un menu d'options sur ses propres posts.
  profilPerso,

  /// Le profil de quelqu'un d'autre : pas d'auteur (la page le dit
  /// déjà), "Enregistrer" disponible.
  profilAutre,
}

/// Une publication (un moment) — pas de carte encadrée : seule la photo
/// est arrondie, le reste s'affiche directement sur le fond de l'écran,
/// comme dans le prototype.
///
/// Composant pur : reçoit tout déjà prêt à afficher ([dateLisible],
/// [libelleReactions]...) et renvoie chaque geste par callback.
class TablPublication extends StatelessWidget {
  const TablPublication({
    super.key,
    required this.contexte,
    required this.auteurPseudo,
    required this.dateLisible,
    required this.photoUrl,
    required this.restaurantNom,
    required this.ville,
    required this.jaiReagi,
    required this.libelleReactions,
    required this.onReagir,
    required this.onCommenter,
    required this.onOuvrirLieu,
    this.emojiEmotion,
    this.legende,
    this.impressions = const [],
    this.enregistre = false,
    this.audienceRestreinte = false,
    this.onEnregistrer,
    this.onOptions,
    this.instantsTotal = 0,
    this.instantsNonVus = 0,
    this.onOuvrirInstants,
    this.onAjouterInstant,
  }) : assert(
         contexte == ContextePublication.profilPerso || onEnregistrer != null,
         '"Enregistrer" est affiché hors de son propre profil : '
         'onEnregistrer est requis.',
       );

  final ContextePublication contexte;
  final String auteurPseudo;
  final String dateLisible;
  final String? photoUrl;
  final String restaurantNom;
  final String ville;
  final String? emojiEmotion;
  final String? legende;
  final List<String> impressions;
  final bool jaiReagi;

  /// Phrase déjà composée ("Martin et 2 autres ont aimé").
  final String libelleReactions;

  final bool enregistre;

  /// Petit cadenas à côté de la date : l'audience n'est pas "Tout le
  /// monde" (ne concerne que ses propres posts).
  final bool audienceRestreinte;

  final VoidCallback onReagir;
  final VoidCallback onCommenter;
  final VoidCallback onOuvrirLieu;

  /// Ignoré sur son propre profil.
  final VoidCallback? onEnregistrer;

  /// Menu "⋯" — affiché seulement sur son propre profil, et seulement si
  /// fourni.
  final VoidCallback? onOptions;

  /// 0 : pas d'Instant actif, aucun signal affiché.
  final int instantsTotal;
  final int instantsNonVus;
  final VoidCallback? onOuvrirInstants;

  /// `null` si ce n'est pas son post, ou si la fenêtre de création est
  /// fermée (megaprompt Bloc 2, règles 3-4).
  final VoidCallback? onAjouterInstant;

  bool get _afficheAuteur => contexte == ContextePublication.feed;

  bool get _afficheEnregistrer => contexte != ContextePublication.profilPerso;

  bool get _afficheOptions =>
      contexte == ContextePublication.profilPerso && onOptions != null;

  @override
  Widget build(BuildContext context) {
    final aDesInstants = instantsTotal > 0 && onOuvrirInstants != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EnTete(
            auteurPseudo: _afficheAuteur ? auteurPseudo : null,
            dateLisible: dateLisible,
            audienceRestreinte: audienceRestreinte,
            onOptions: _afficheOptions ? onOptions : null,
          ),
          _Photo(
            photoUrl: photoUrl,
            restaurantNom: restaurantNom,
            ville: ville,
            emojiEmotion: emojiEmotion,
            onOuvrirLieu: onOuvrirLieu,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TablTokens.espaceL + TablTokens.espaceXs,
              26,
              TablTokens.espaceL + TablTokens.espaceXs,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (legende != null)
                  Text(
                    legende!,
                    style: TablTokens.titreAffichage.copyWith(fontSize: 16),
                  ),
                if (impressions.isNotEmpty) ...[
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final impression in impressions.take(2))
                        _PuceImpression(texte: impression),
                      if (impressions.length > 2)
                        Text(
                          '+${impressions.length - 2}',
                          style: TablTokens.legende,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 15),
                Row(
                  children: [
                    _ActionTabler(actif: jaiReagi, onPresse: onReagir),
                    _ActionTexte(
                      icone: Icons.mode_comment_outlined,
                      libelle: 'Commenter',
                      onPresse: onCommenter,
                    ),
                    const Spacer(),
                    if (_afficheEnregistrer)
                      _ActionTexte(
                        icone: enregistre
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        libelle: enregistre ? 'Enregistrée' : 'Enregistrer',
                        actif: enregistre,
                        onPresse: onEnregistrer!,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  libelleReactions,
                  style: TablTokens.legende.copyWith(
                    color: TablTokens.texteDoux.withValues(alpha: 0.9),
                  ),
                ),
                if (aDesInstants || onAjouterInstant != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (aDesInstants)
                        TablSignalInstants(
                          total: instantsTotal,
                          nonVus: instantsNonVus,
                          onPresse: onOuvrirInstants!,
                        ),
                      if (aDesInstants && onAjouterInstant != null)
                        const SizedBox(width: TablTokens.espaceM),
                      if (onAjouterInstant != null)
                        TablBoutonAjouterInstant(onPresse: onAjouterInstant!),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne au-dessus de la photo : auteur (Feed seulement), date, et menu
/// d'options (son propre profil seulement).
class _EnTete extends StatelessWidget {
  const _EnTete({
    required this.auteurPseudo,
    required this.dateLisible,
    required this.audienceRestreinte,
    required this.onOptions,
  });

  /// `null` : auteur masqué.
  final String? auteurPseudo;
  final String dateLisible;
  final bool audienceRestreinte;
  final VoidCallback? onOptions;

  @override
  Widget build(BuildContext context) {
    final date = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (audienceRestreinte) ...[
          const Icon(
            Icons.lock_outline_rounded,
            size: 11,
            color: TablTokens.texteDoux,
          ),
          const SizedBox(width: 4),
        ],
        Text(dateLisible, style: TablTokens.legende.copyWith(fontSize: 11)),
      ],
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        TablTokens.espaceL,
        0,
        // Le bouton "⋯" a sa propre zone de tap : on rogne la marge pour
        // garder l'icône alignée sur le bord de la photo.
        onOptions != null ? TablTokens.espaceS : TablTokens.espaceL,
        10,
      ),
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            if (auteurPseudo != null) ...[
              _Avatar(pseudo: auteurPseudo!),
              const SizedBox(width: TablTokens.espaceS),
              Expanded(
                child: Text(
                  auteurPseudo!,
                  overflow: TextOverflow.ellipsis,
                  style: TablTokens.corps.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              date,
            ] else ...[
              date,
              const Spacer(),
            ],
            if (onOptions != null)
              IconButton(
                onPressed: onOptions,
                tooltip: 'Options',
                icon: const Icon(Icons.more_horiz_rounded, size: 20),
                color: TablTokens.texteDoux,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 28,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({
    required this.photoUrl,
    required this.restaurantNom,
    required this.ville,
    required this.emojiEmotion,
    required this.onOuvrirLieu,
  });

  final String? photoUrl;
  final String restaurantNom;
  final String ville;
  final String? emojiEmotion;
  final VoidCallback onOuvrirLieu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TablTokens.espaceM),
      child: Stack(
        // La pastille d'émotion déborde volontairement sous la photo.
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: AspectRatio(
              aspectRatio: 1 / 1.06,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: TablTokens.surface),
                  if (photoUrl != null)
                    Image.network(
                      photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => const SizedBox(),
                    ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.18),
                            Colors.black.withValues(alpha: 0.62),
                            Colors.black.withValues(alpha: 0.9),
                          ],
                          stops: const [0.4, 0.62, 0.83, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 13,
                    child: GestureDetector(
                      onTap: onOuvrirLieu,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 15,
                                color: TablTokens.primaire,
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  restaurantNom,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFF8F4EE),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 22, top: 1),
                            child: Text(
                              ville,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.white.withValues(alpha: 0.64),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (emojiEmotion != null)
            Positioned(
              left: 10,
              bottom: -19,
              child: Container(
                width: 37,
                height: 37,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TablTokens.fond.withValues(alpha: 0.62),
                  border: Border.all(
                    color: TablTokens.primaire.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(emojiEmotion!, style: const TextStyle(fontSize: 19)),
              ),
            ),
        ],
      ),
    );
  }
}

class _PuceImpression extends StatelessWidget {
  const _PuceImpression({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: TablTokens.texte.withValues(alpha: 0.075)),
        color: TablTokens.texte.withValues(alpha: 0.022),
      ),
      child: Text(
        texte,
        style: TextStyle(
          fontSize: 11.5,
          color: TablTokens.texte.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

/// Bouton "J'aime" : reprend l'animation cloche + cœur déjà en place
/// (identité de marque), avec le libellé dynamique du prototype
/// ("J'aime" / "Aimé").
class _ActionTabler extends StatelessWidget {
  const _ActionTabler({required this.actif, required this.onPresse});

  final bool actif;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: TablTokens.espaceS),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TablBoutonReaction(actif: actif, onPresse: onPresse),
          Text(
            actif ? 'Aimé' : "J'aime",
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: actif ? FontWeight.w600 : FontWeight.w500,
              color: actif ? TablTokens.primaire : TablTokens.texteDoux,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTexte extends StatelessWidget {
  const _ActionTexte({
    required this.icone,
    required this.libelle,
    required this.onPresse,
    this.actif = false,
  });

  final IconData icone;
  final String libelle;
  final bool actif;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    final couleur = actif ? TablTokens.primaire : TablTokens.texteDoux;
    return TextButton.icon(
      onPressed: onPresse,
      style: TextButton.styleFrom(
        foregroundColor: couleur,
        padding: const EdgeInsets.symmetric(horizontal: TablTokens.espaceXs),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icone, size: 19, color: couleur),
      label: Text(
        libelle,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: actif ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.pseudo});

  final String pseudo;

  @override
  Widget build(BuildContext context) {
    final initiale = pseudo.isEmpty ? '?' : pseudo[0].toUpperCase();
    return CircleAvatar(
      radius: 12,
      backgroundColor: TablTokens.primaire.withValues(alpha: 0.85),
      child: Text(
        initiale,
        style: TablTokens.legende.copyWith(
          fontSize: 11,
          color: TablTokens.texteSurPrimaire,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
