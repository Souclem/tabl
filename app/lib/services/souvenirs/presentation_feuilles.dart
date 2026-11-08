import '../restaurants/categories_lieu.dart';
import '../social/profil_public.dart';
import 'nouveau_souvenir.dart';
import 'precompletion_souvenir.dart';

/// Le repas qu'on dit avoir fait quand l'heure de la prise ne dit rien de
/// sûr (« Où et quand ») : midi à 12 h 30, soir à 20 h.
const _heureMidi = (heure: 12, minute: 30);
const _heureSoir = (heure: 20, minute: 0);

/// Le moment stocké (`midi` / `soir`) d'un moment en création.
String momentDuBrouillon(DateTime priseLe) => momentDuJour(priseLe);

/// L'heure de repas à garder quand on choisit [moment] : inchangée si la
/// prise est déjà de ce moment, sinon le même jour à l'heure habituelle du
/// repas.
DateTime priseLePourMoment(DateTime priseLe, String moment) {
  if (momentDuBrouillon(priseLe) == moment) return priseLe;
  final heure = moment == 'midi' ? _heureMidi : _heureSoir;
  return DateTime(
    priseLe.year,
    priseLe.month,
    priseLe.day,
    heure.heure,
    heure.minute,
  );
}

/// Un moment se publie avec une à dix photos.
bool nombrePhotosPublicable(int nombre) =>
    nombre >= 1 && nombre <= nombreMaxPhotosSouvenir;

/// Le nom d'une photo dans « Photos du moment » : la première est la
/// couverture.
String titrePhotoMoment(int rang) =>
    rang == 0 ? 'Couverture' : 'Photo ${rang + 1}';

/// « 3 / 10 à publier ».
String compteurPhotosAPublier(int aPublier) =>
    '$aPublier / $nombreMaxPhotosSouvenir à publier';

/// Ce qui empêche de valider « Photos du moment », ou `null` : trop de
/// photos à publier (le choix), ou aucune.
String? consignePhotos({required int aPublier, required int total}) {
  if (aPublier > nombreMaxPhotosSouvenir) {
    final enTrop = aPublier - nombreMaxPhotosSouvenir;
    return 'Un moment garde $nombreMaxPhotosSouvenir photos au plus : '
        'retirez-en $enTrop de la publication.';
  }
  if (aPublier == 0 && total > 0) {
    return 'Gardez au moins une photo à publier.';
  }
  return null;
}

/// Les personnes dont le pseudo contient [texte] (sans accent ni casse) ;
/// toutes si [texte] est vide.
List<ProfilPublic> filtrerPersonnes(
  List<ProfilPublic> personnes,
  String texte,
) {
  final cherche = normaliserPourRecherche(texte.trim());
  if (cherche.isEmpty) return personnes;
  return [
    for (final p in personnes)
      if (normaliserPourRecherche(p.pseudo).contains(cherche)) p,
  ];
}
