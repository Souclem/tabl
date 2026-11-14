import 'package:supabase_flutter/supabase_flutter.dart';

/// Le rang d'un moment parmi ceux que je publie sur un même restaurant,
/// écrit pour l'affichage : « 1re fois ici », « 2e fois ici »…
String libelleNiemeFois(int rang) =>
    rang <= 1 ? '1re fois ici' : '${rang}e fois ici';

/// D'où vient le nombre de moments publiés : un seul point d'entrée, que
/// les tests remplacent.
abstract interface class SourceVisites {
  /// Mes moments publiés sur ce restaurant, ceux d'un ancien repas ajouté
  /// après coup compris. Les brouillons ne comptent pas.
  Future<int> nombreMomentsPublies(String restaurantId);
}

/// Compte mes moments publiés sur un restaurant, pour la puce « n-ième fois
/// ici » à la fin de la publication.
class CompteurVisites {
  CompteurVisites(this._source);

  final SourceVisites _source;

  /// Le texte de la puce, une fois le moment publié (il est alors compté :
  /// le premier moment sur un lieu donne « 1re fois ici »). `null` si rien
  /// n'est publié sur ce restaurant ou si le compte est impossible : la
  /// puce est alors simplement absente, jamais une publication en échec.
  Future<String?> libelle(String restaurantId) async {
    try {
      final nombre = await _source.nombreMomentsPublies(restaurantId);
      return nombre < 1 ? null : libelleNiemeFois(nombre);
    } on Object {
      return null;
    }
  }
}

/// [SourceVisites] adossée à Supabase : table `souvenirs`, lue avec les
/// droits de l'auteur (aucune migration, aucune policy nouvelle).
class SourceVisitesSupabase implements SourceVisites {
  SourceVisitesSupabase(this._client);

  final SupabaseClient _client;

  @override
  Future<int> nombreMomentsPublies(String restaurantId) async {
    final lignes = await _client
        .from('souvenirs')
        .select('id')
        .eq('auteur_id', _client.auth.currentSession!.user.id)
        .eq('restaurant_id', restaurantId)
        .eq('statut', 'publie');
    return lignes.length;
  }
}
