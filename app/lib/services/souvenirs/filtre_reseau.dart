import 'package:supabase_flutter/supabase_flutter.dart';

/// Condition PostgREST (pour `.or()`) qui limite des souvenirs à « mon
/// réseau » : les miens, ceux des personnes que je suis, et ceux qui
/// m'ont été adressés nommément ou via une Table ("Seulement…"). La RLS
/// laisse aussi lire les posts de tous les profils publics : sans ce
/// filtre, ceux d'inconnus apparaîtraient. Partagée par le Feed et la
/// carte, pour qu'ils montrent exactement le même réseau.
Future<String> conditionSouvenirsDuReseau(
  SupabaseClient client,
  String monId,
) async {
  final suivis = await client
      .from('abonnements')
      .select('suivi_id')
      .eq('suiveur_id', monId)
      .eq('statut', 'accepte');
  final auteurs = [monId, ...suivis.map((l) => l['suivi_id'] as String)];
  return 'auteur_id.in.(${auteurs.join(',')}),visibilite.eq.seulement';
}
