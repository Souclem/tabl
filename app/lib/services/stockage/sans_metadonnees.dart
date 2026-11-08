import 'dart:typed_data';

/// La photo telle qu'on l'envoie : la même image, sans ce qu'elle dit
/// d'elle-même (position GPS, date, appareil, légendes…). Seul le sens
/// de l'image (orientation EXIF) est gardé, sinon elle s'afficherait
/// couchée.
///
/// `image_picker` recopie toutes les métadonnées d'origine dans l'image
/// réduite (iOS comme Android) : sans ça, n'importe qui pouvant voir la
/// photo — une photo de profil est publique — lisait où elle a été
/// prise. La date et la position servent à préremplir un souvenir : on
/// les lit sur le téléphone ([lireMetadonnees]) avant d'appeler ceci.
///
/// JPEG et PNG, sans réencodage (aucune perte de qualité) ; tout autre
/// format, ou un fichier illisible, est rendu tel quel.
Uint8List sansMetadonnees(Uint8List octets) {
  if (_commencePar(octets, const [0xFF, 0xD8])) {
    return _jpegSansMetadonnees(octets) ?? octets;
  }
  if (_commencePar(octets, _signaturePng)) {
    return _pngSansMetadonnees(octets) ?? octets;
  }
  return octets;
}

const _signaturePng = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

bool _commencePar(Uint8List octets, List<int> debut) {
  if (octets.length < debut.length) return false;
  for (var i = 0; i < debut.length; i++) {
    if (octets[i] != debut[i]) return false;
  }
  return true;
}

/// Les segments d'un JPEG, un par un, triés par [_garderSegment]. Ce qui
/// suit la fin de l'image (une 2e image collée derrière) est jeté aussi.
/// `null` si le fichier est mal formé.
Uint8List? _jpegSansMetadonnees(Uint8List o) {
  final sortie = BytesBuilder(copy: false)..add(const [0xFF, 0xD8]);
  var i = 2;
  var dansLesDonnees = false;
  while (i < o.length) {
    if (dansLesDonnees) {
      // Données compressées : un 0xFF n'y est un marqueur que s'il
      // n'est suivi ni de 0x00 (octet échappé) ni d'un RSTn.
      final debut = i;
      while (i + 1 < o.length &&
          !(o[i] == 0xFF && o[i + 1] != 0x00 && !_estRst(o[i + 1]))) {
        i++;
      }
      if (i + 1 >= o.length) {
        // Image tronquée : on garde ce qui est là.
        sortie.add(Uint8List.sublistView(o, debut));
        return sortie.takeBytes();
      }
      sortie.add(Uint8List.sublistView(o, debut, i));
      dansLesDonnees = false;
      continue;
    }
    if (o[i] != 0xFF) return null;
    // Octets de remplissage avant un marqueur.
    while (i + 1 < o.length && o[i + 1] == 0xFF) {
      i++;
    }
    if (i + 1 >= o.length) return null;
    final marqueur = o[i + 1];
    if (marqueur == 0xD9) {
      sortie.add(const [0xFF, 0xD9]);
      return sortie.takeBytes();
    }
    if (_estRst(marqueur) || marqueur == 0x01) {
      sortie.add([0xFF, marqueur]);
      i += 2;
      continue;
    }
    if (i + 4 > o.length) return null;
    final longueur = (o[i + 2] << 8) | o[i + 3];
    final fin = i + 2 + longueur;
    if (longueur < 2 || fin > o.length) return null;
    final contenu = Uint8List.sublistView(o, i + 4, fin);
    if (_garderSegment(marqueur, contenu)) {
      sortie.add(Uint8List.sublistView(o, i, fin));
    } else if (marqueur == 0xE1) {
      // EXIF : on n'en garde que l'orientation (XMP : rien).
      if (_orientationExif(contenu) case final orientation?) {
        sortie.add(_exifOrientation(orientation));
      }
    }
    i = fin;
    // Après l'en-tête d'un balayage (SOS) viennent ses données.
    if (marqueur == 0xDA) dansLesDonnees = true;
  }
  return sortie.takeBytes();
}

bool _estRst(int marqueur) => marqueur >= 0xD0 && marqueur <= 0xD7;

/// Tout ce qui décrit l'image (tables, dimensions, données) ; parmi les
/// segments d'application, seulement JFIF (APP0), le profil de couleurs
/// (APP2 « ICC_PROFILE ») et Adobe (APP14, utile au décodage des
/// couleurs). Le reste part : EXIF, XMP, IPTC, commentaires…
bool _garderSegment(int marqueur, Uint8List contenu) {
  if (marqueur == 0xFE) return false;
  if (marqueur < 0xE0 || marqueur > 0xEF) return true;
  return marqueur == 0xE0 ||
      marqueur == 0xEE ||
      (marqueur == 0xE2 && _commencePar(contenu, _profilIcc));
}

/// « ICC_PROFILE », terminé par un zéro.
final _profilIcc = [...'ICC_PROFILE'.codeUnits, 0];

/// L'orientation (1 à 8) d'un segment APP1 EXIF, si elle n'est pas
/// « droite » (1). `null` sinon, ou si le segment est illisible.
int? _orientationExif(Uint8List c) {
  const entete = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00]; // « Exif\0\0 »
  if (!_commencePar(c, entete) || c.length < 6 + 8) return null;
  final tiff = ByteData.sublistView(c, 6);
  final Endian ordre;
  if (tiff.getUint16(0) == 0x4949) {
    ordre = Endian.little;
  } else if (tiff.getUint16(0) == 0x4D4D) {
    ordre = Endian.big;
  } else {
    return null;
  }
  final ifd = tiff.getUint32(4, ordre);
  if (ifd + 2 > tiff.lengthInBytes) return null;
  final nombre = tiff.getUint16(ifd, ordre);
  for (var n = 0; n < nombre; n++) {
    final entree = ifd + 2 + n * 12;
    if (entree + 12 > tiff.lengthInBytes) return null;
    // 0x0112 = Orientation, de type SHORT (3).
    if (tiff.getUint16(entree, ordre) == 0x0112 &&
        tiff.getUint16(entree + 2, ordre) == 3) {
      final valeur = tiff.getUint16(entree + 8, ordre);
      return valeur >= 2 && valeur <= 8 ? valeur : null;
    }
  }
  return null;
}

/// Un segment APP1 EXIF qui ne contient que l'orientation.
Uint8List _exifOrientation(int orientation) => Uint8List.fromList([
  0xFF, 0xE1, 0x00, 0x22, // APP1, 34 octets
  0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // « Exif\0\0 »
  0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08, // TIFF, grand-boutiste
  0x00, 0x01, // une seule entrée
  0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, // Orientation, SHORT, 1
  0x00, orientation, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, // pas d'IFD suivant
]);

/// Les morceaux d'un PNG, sans ceux qui portent des métadonnées (EXIF,
/// textes, date). `null` si le fichier est mal formé.
Uint8List? _pngSansMetadonnees(Uint8List o) {
  const jetes = {'eXIf', 'tEXt', 'zTXt', 'iTXt', 'tIME'};
  final sortie = BytesBuilder(copy: false)..add(_signaturePng);
  final donnees = ByteData.sublistView(o);
  var i = _signaturePng.length;
  while (i + 12 <= o.length) {
    final longueur = donnees.getUint32(i);
    final fin = i + 12 + longueur;
    if (fin > o.length) return null;
    final type = String.fromCharCodes(o, i + 4, i + 8);
    if (!jetes.contains(type)) sortie.add(Uint8List.sublistView(o, i, fin));
    i = fin;
    if (type == 'IEND') return sortie.takeBytes();
  }
  return null;
}
