import 'dart:typed_data';

/// Ce dont parle un message envoyé depuis « Aide et contact ».
enum TypeRetour {
  bug(
    'bug',
    'Un bug',
    'Quelque chose ne marche pas',
    'Que s’est-il passé ? Qu’attendais-tu à la place ?',
  ),
  idee(
    'idee',
    'Une idée',
    'Pour rendre Tabl meilleur',
    'Raconte-nous ton idée : qu’est-ce que ça changerait pour toi ?',
  ),
  pasClair(
    'pas_clair',
    'Pas clair',
    'Je ne comprends pas comment faire',
    'Qu’essayais-tu de faire, et qu’est-ce qui t’a perdu ?',
  ),
  lieu(
    'lieu',
    'Un lieu à corriger',
    'Manquant, fermé, mal placé…',
    'Quel lieu, dans quelle ville, et qu’est-ce qui ne va pas ?',
  ),
  signalement(
    'signalement',
    'Signaler un contenu',
    'Un moment ou un compte qui pose problème',
    'Quel moment ou quel compte, et pourquoi ?',
  ),
  autre(
    'autre',
    'Autre chose',
    'Une question, un mot pour l’équipe',
    'On t’écoute…',
  );

  const TypeRetour(this.valeur, this.libelle, this.description, this.invite);

  /// La valeur en base (`retours.type`).
  final String valeur;

  /// "Un bug".
  final String libelle;

  /// "Quelque chose ne marche pas".
  final String description;

  /// Le texte d'aide du champ, une fois ce type choisi.
  final String invite;
}

/// Trois captures au plus par message (même limite en base).
const nombreMaxCaptures = 3;

/// Longueur maximale d'un message (même limite en base).
const longueurMaxRetour = 2000;

/// Un message peut partir dès qu'on a dit de quoi il s'agit et écrit
/// quelques mots.
bool peutEnvoyerRetour(TypeRetour? type, String texte) =>
    type != null &&
    texte.trim().isNotEmpty &&
    texte.trim().length <= longueurMaxRetour;

/// L'extension et le type d'une capture d'après ses premiers octets :
/// une capture d'écran reste souvent en PNG, une photo en JPEG.
({String extension, String typeMime}) formatCapture(Uint8List octets) {
  const signaturePng = [0x89, 0x50, 0x4E, 0x47];
  final estPng =
      octets.length >= 4 &&
      List.generate(4, (i) => octets[i] == signaturePng[i]).every((ok) => ok);
  return estPng
      ? (extension: 'png', typeMime: 'image/png')
      : (extension: 'jpg', typeMime: 'image/jpeg');
}
