import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'avatar.dart';
import 'bouton_reaction.dart';
import 'bulles_personnes.dart';
import 'indicateur_page.dart';
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
  // Géométrie de la photo, publique pour qu'une vignette puisse s'animer
  // exactement jusqu'à sa place (avis qui s'agrandit sur place).

  /// Hauteur de la ligne au-dessus de la photo (auteur, date), marge
  /// comprise.
  static const hauteurEnTete = 38.0;

  /// Marge à gauche et à droite de la photo.
  static const margePhoto = TablTokens.espaceM;

  /// Hauteur de la photo par rapport à sa largeur.
  static const proportionPhoto = 1.06;
  static const arrondiPhoto = 26.0;

  const TablPublication({
    super.key,
    required this.contexte,
    required this.auteurPseudo,
    required this.dateLisible,
    required this.photoUrl,
    this.autresPhotosUrls = const [],
    this.auteurPhotoUrl,
    required this.restaurantNom,
    required this.ville,
    required this.jaiReagi,
    required this.libelleReactions,
    this.bullesReactions = const [],
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
    this.onTapAuteur,
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

  /// Photo de profil de l'auteur (Feed seulement).
  final String? auteurPhotoUrl;
  final String dateLisible;
  final String? photoUrl;

  /// Les autres photos du moment, après la principale : on les fait
  /// défiler du doigt.
  final List<String> autresPhotosUrls;
  final String restaurantNom;
  final String ville;
  final String? emojiEmotion;
  final String? legende;
  final List<String> impressions;
  final bool jaiReagi;

  /// Phrase déjà composée ("Martin et 2 autres ont aimé").
  final String libelleReactions;

  /// Les têtes de ceux que je suis parmi eux, à côté de la phrase (3 au
  /// plus) ; vide : rien à côté.
  final List<BullePersonne> bullesReactions;

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

  /// Tap sur l'avatar ou le pseudo de l'auteur (ouvre son profil) ;
  /// `null` : pas touchable.
  final VoidCallback? onTapAuteur;

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
            auteurPhotoUrl: auteurPhotoUrl,
            dateLisible: dateLisible,
            audienceRestreinte: audienceRestreinte,
            onOptions: _afficheOptions ? onOptions : null,
            onTapAuteur: onTapAuteur,
          ),
          _Photo(
            photoUrls: [?photoUrl, ...autresPhotosUrls],
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
                        TablPuceImpression(texte: impression),
                      if (impressions.length > 2)
                        Text(
                          '+${impressions.length - 2}',
                          style: TablTokens.legende,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 15),
                TablActionsPublication(
                  jaiReagi: jaiReagi,
                  onReagir: onReagir,
                  onCommenter: onCommenter,
                  enregistre: enregistre,
                  onEnregistrer: _afficheEnregistrer ? onEnregistrer : null,
                ),
                const SizedBox(height: 4),
                TablLigneReactions(
                  libelle: libelleReactions,
                  bulles: bullesReactions,
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
    required this.auteurPhotoUrl,
    required this.dateLisible,
    required this.audienceRestreinte,
    required this.onOptions,
    required this.onTapAuteur,
  });

  /// `null` : auteur masqué.
  final String? auteurPseudo;
  final String? auteurPhotoUrl;
  final String dateLisible;
  final bool audienceRestreinte;
  final VoidCallback? onOptions;
  final VoidCallback? onTapAuteur;

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
        TablPublication.hauteurEnTete - 28,
      ),
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            if (auteurPseudo != null) ...[
              Expanded(
                child: GestureDetector(
                  onTap: onTapAuteur,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      TablAvatar(
                        pseudo: auteurPseudo!,
                        photoUrl: auteurPhotoUrl,
                      ),
                      const SizedBox(width: TablTokens.espaceS),
                      Flexible(
                        child: Text(
                          auteurPseudo!,
                          overflow: TextOverflow.ellipsis,
                          style: TablTokens.corps.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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

class _Photo extends StatefulWidget {
  const _Photo({
    required this.photoUrls,
    required this.restaurantNom,
    required this.ville,
    required this.emojiEmotion,
    required this.onOuvrirLieu,
  });

  /// La principale d'abord ; vide : pas de photo.
  final List<String> photoUrls;
  final String restaurantNom;
  final String ville;
  final String? emojiEmotion;
  final VoidCallback onOuvrirLieu;

  @override
  State<_Photo> createState() => _PhotoState();
}

class _PhotoState extends State<_Photo> {
  int _page = 0;

  Widget _image(String url) => Image.network(
    url,
    fit: BoxFit.cover,
    errorBuilder: (context, error, stack) => const SizedBox(),
  );

  @override
  Widget build(BuildContext context) {
    final photoUrls = widget.photoUrls;
    final restaurantNom = widget.restaurantNom;
    final ville = widget.ville;
    final emojiEmotion = widget.emojiEmotion;
    final onOuvrirLieu = widget.onOuvrirLieu;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TablPublication.margePhoto,
      ),
      child: Stack(
        // La pastille d'émotion déborde volontairement sous la photo.
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(TablPublication.arrondiPhoto),
            child: AspectRatio(
              aspectRatio: 1 / TablPublication.proportionPhoto,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: TablTokens.surface),
                  if (photoUrls.length > 1)
                    PageView(
                      onPageChanged: (page) => setState(() => _page = page),
                      children: [for (final url in photoUrls) _image(url)],
                    )
                  else if (photoUrls.isNotEmpty)
                    _image(photoUrls.first),
                  // Le dégradé ne fait que se voir : touchable, il
                  // retiendrait le doigt, et les photos ne défileraient
                  // plus.
                  Positioned.fill(
                    child: IgnorePointer(
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
                  ),
                  if (photoUrls.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 12,
                      child: IgnorePointer(
                        child: Center(
                          child: TablIndicateurPage(
                            total: photoUrls.length,
                            index: _page,
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
                child: Text(emojiEmotion, style: const TextStyle(fontSize: 19)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Une impression ("Assiette · Exceptionnelle") en petite pastille.
class TablPuceImpression extends StatelessWidget {
  const TablPuceImpression({super.key, required this.texte});

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

/// La rangée d'actions sous un moment : J'aime, Commenter, et
/// Enregistrer à droite quand [onEnregistrer] est fourni.
class TablActionsPublication extends StatelessWidget {
  const TablActionsPublication({
    super.key,
    required this.jaiReagi,
    required this.onReagir,
    required this.onCommenter,
    this.enregistre = false,
    this.onEnregistrer,
  });

  final bool jaiReagi;
  final VoidCallback onReagir;
  final VoidCallback onCommenter;
  final bool enregistre;

  /// `null` : pas de bouton Enregistrer (son propre moment).
  final VoidCallback? onEnregistrer;

  @override
  Widget build(BuildContext context) {
    // Rien que des icônes : le geste se comprend tout seul. Le nom de
    // chaque action reste dans l'info-bulle et pour les lecteurs d'écran.
    return Row(
      children: [
        TablBoutonReaction(actif: jaiReagi, onPresse: onReagir),
        _ActionIcone(
          icone: Icons.mode_comment_outlined,
          libelle: 'Commenter',
          onPresse: onCommenter,
        ),
        const Spacer(),
        if (onEnregistrer != null)
          _ActionIcone(
            icone: enregistre
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            libelle: enregistre ? 'Enregistrée' : 'Enregistrer',
            actif: enregistre,
            onPresse: onEnregistrer!,
          ),
      ],
    );
  }
}

/// Sous les actions d'un moment : qui l'a aimé, en une phrase, avec la
/// tête de ceux que je suis devant.
class TablLigneReactions extends StatelessWidget {
  const TablLigneReactions({
    super.key,
    required this.libelle,
    this.bulles = const [],
  });

  /// "Martin, Sarah et 12 autres ont aimé".
  final String libelle;

  /// 3 au plus ; vide : la phrase seule.
  final List<BullePersonne> bulles;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (bulles.isNotEmpty) ...[
          TablBullesPersonnes(bulles: bulles, taille: 22),
          const SizedBox(width: TablTokens.espaceS),
        ],
        Flexible(
          child: Text(
            libelle,
            style: TablTokens.legende.copyWith(
              color: TablTokens.texteDoux.withValues(alpha: 0.9),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionIcone extends StatelessWidget {
  const _ActionIcone({
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
    return IconButton(
      onPressed: onPresse,
      tooltip: libelle,
      icon: Icon(
        icone,
        size: 23,
        color: actif ? TablTokens.primaire : TablTokens.texteDoux,
      ),
    );
  }
}
