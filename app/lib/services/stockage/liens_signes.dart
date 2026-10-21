import 'package:supabase_flutter/supabase_flutter.dart';

/// Validité d'un lien signé vers une photo d'un bucket privé.
const dureeLienSigne = Duration(days: 7);

/// Un lien gardé en mémoire n'est redonné que s'il vaut encore au moins
/// ce temps : l'écran qui le reçoit peut rester ouvert des jours.
const margeLienSigne = Duration(days: 3);

/// Les adresses affichables des photos des buckets privés (`souvenirs`,
/// `instants`) : chemin dans le bucket → lien signé. Un chemin que la
/// base refuse de signer est absent du résultat.
///
/// Un écran garde ses données tant que l'app reste ouverte, parfois des
/// jours en arrière-plan. Avec des liens d'une heure, une photo sortie
/// du cache d'images ne se rechargeait plus (400, « "exp" claim
/// timestamp check failed ») et restait vide. D'où des liens d'une
/// semaine, jamais redonnés quand ils valent moins de [margeLienSigne].
///
/// Gardés en mémoire, ils gardent aussi la même adresse d'un chargement
/// à l'autre : le cache d'images de Flutter reconnaît une photo déjà
/// vue, elle n'est ni retéléchargée ni redécodée.
///
/// Le revers : un lien donné reste valable jusqu'à sa fin, même si
/// l'auteur rend ensuite sa publication privée. Il ne vit que dans la
/// mémoire de l'app de quelqu'un qui avait le droit de la voir.
Future<Map<String, String>> liensSignes(
  SupabaseClient client,
  String bucket,
  Iterable<String> chemins,
) async {
  // Un autre compte sur le téléphone : il repart de zéro.
  final moi = client.auth.currentUser?.id;
  if (moi != _proprietaire) {
    _memoire.vider();
    _proprietaire = moi;
  }

  // Compté avant la demande : la fin retenue n'est jamais plus tard
  // que la vraie.
  final maintenant = DateTime.now();
  final (:connus, :aSigner) = _memoire.trier(bucket, chemins, maintenant);
  if (aSigner.isEmpty) return connus;

  final resultats = await client.storage
      .from(bucket)
      .createSignedUrlsResult(aSigner, dureeLienSigne.inSeconds);
  final expireLe = maintenant.add(dureeLienSigne);
  for (final resultat in resultats) {
    if (resultat is SignedUrlSuccess) {
      _memoire.retenir(bucket, resultat.path, resultat.signedUrl, expireLe);
      connus[resultat.path] = resultat.signedUrl;
    }
  }
  return connus;
}

final _memoire = MemoireLiens();
String? _proprietaire;

/// Les liens déjà signés, par bucket et chemin, avec leur fin.
class MemoireLiens {
  final _liens = <String, ({String url, DateTime expireLe})>{};

  /// Ceux qu'on peut redonner tels quels, et ceux à (re)signer, sans
  /// doublon.
  ({Map<String, String> connus, List<String> aSigner}) trier(
    String bucket,
    Iterable<String> chemins,
    DateTime maintenant,
  ) {
    final connus = <String, String>{};
    final aSigner = <String>{};
    for (final chemin in chemins) {
      final lien = _liens['$bucket/$chemin'];
      if (lien != null &&
          lien.expireLe.difference(maintenant) >= margeLienSigne) {
        connus[chemin] = lien.url;
      } else {
        aSigner.add(chemin);
      }
    }
    return (connus: connus, aSigner: aSigner.toList());
  }

  void retenir(String bucket, String chemin, String url, DateTime expireLe) =>
      _liens['$bucket/$chemin'] = (url: url, expireLe: expireLe);

  void vider() => _liens.clear();
}
