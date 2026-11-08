import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'creation_moment.dart';
import 'ecran_ajouter_souvenir.dart';
import 'ecran_import_souvenirs.dart';

/// « Comment retrouver vos souvenirs ? » : un repas à partir de ses
/// photos (pas de souvenir sans photo), ou plusieurs d'un coup. Se ferme
/// sur le nombre de souvenirs ajoutés, dès qu'il y en a.
class EcranChoixSouvenir extends StatelessWidget {
  const EcranChoixSouvenir({
    super.key,
    required this.souvenirService,
    required this.abonnementService,
    this.tableService,
    this.rechercheLieuService,
    this.positionService,
    this.photosRecentes = const [],
    this.choisirPhotos = photosDuTelephone,
  });

  final SouvenirService souvenirService;
  final AbonnementService abonnementService;
  final TableService? tableService;
  final RechercheLieuService? rechercheLieuService;
  final PositionService? positionService;

  /// Ses dernières photos, pour garnir la pile de la carte.
  final List<String> photosRecentes;
  final ChoisirPhotos choisirPhotos;

  Future<void> _choisirPhotos(BuildContext context) async {
    final List<PhotoChoisie> photos;
    try {
      photos = await lirePhotos(await choisirPhotos(nombreMaxPhotosSouvenir));
    } catch (e) {
      debugPrint('EcranChoixSouvenir: photos : $e');
      if (context.mounted) afficherMessage(context, messageErreurGenerique);
      return;
    }
    // Sélecteur fermé sans rien choisir : on reste ici.
    if (photos.isEmpty || !context.mounted) return;
    await _ouvrir(context, photos);
  }

  Future<void> _ouvrir(BuildContext context, List<PhotoChoisie> photos) async {
    final ajoute = await Navigator.of(context).push<NouveauSouvenir>(
      MaterialPageRoute(
        builder: (_) => EcranAjouterSouvenir(
          souvenirService: souvenirService,
          abonnementService: abonnementService,
          photos: photos,
          tableService: tableService,
          rechercheLieuService: rechercheLieuService,
          positionService: positionService,
          choisirPhotos: choisirPhotos,
        ),
      ),
    );
    if (ajoute != null && context.mounted) Navigator.of(context).pop(1);
  }

  Future<void> _importer(BuildContext context) async {
    final ajoutes = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => EcranImportSouvenirs(
          souvenirService: souvenirService,
          abonnementService: abonnementService,
          tableService: tableService,
          rechercheLieuService: rechercheLieuService,
          positionService: positionService,
          choisirPhotos: choisirPhotos,
        ),
      ),
    );
    if ((ajoutes ?? 0) > 0 && context.mounted) {
      Navigator.of(context).pop(ajoutes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Scaffold(
      backgroundColor: c.fond,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            TablTokens.espaceL - 4,
            TablTokens.espaceS,
            TablTokens.espaceL - 4,
            TablTokens.espaceL,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TablBoutonRetour(
                onPresse: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: TablTokens.espaceL),
            const TablSurtitreSouvenir(texte: 'Souvenirs'),
            const SizedBox(height: TablTokens.espaceS),
            Text(
              'Comment retrouver vos souvenirs ?',
              style: c.titreAffichage.copyWith(fontSize: 32, height: 1.12),
            ),
            const SizedBox(height: TablTokens.espaceS),
            Text(
              'Vos repas passés se rangent à leur date sur votre profil, '
              'jamais dans le Feed.',
              style: c.legende.copyWith(fontSize: 14),
            ),
            const SizedBox(height: TablTokens.espaceL),
            TablCarteAjoutSouvenir(
              titre: 'Ajouter un souvenir',
              texte:
                  'Choisissez les photos d\'un repas : Tabl retrouve le '
                  'restaurant, le jour et le moment. Vous n\'avez plus qu\'à '
                  'vérifier.',
              libelleBouton: 'Choisir des photos',
              onChoisirPhotos: () => _choisirPhotos(context),
              photosUrls: photosRecentes,
            ),
            const SizedBox(height: TablTokens.espaceM),
            TablMethodeSouvenir(
              icone: Icons.auto_awesome_outlined,
              titre: 'Ajouter plusieurs de manière intelligente',
              texte: 'Tabl range vos photos en repas, vous vérifiez.',
              onPresse: () => _importer(context),
            ),
            const SizedBox(height: TablTokens.espaceL),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded, size: 13, color: c.texteDoux),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Tabl ne lit que la date et le lieu des photos choisies.',
                    style: c.legende.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
