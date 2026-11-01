import 'package:supabase_flutter/supabase_flutter.dart';

/// Les personnes que je suis (demande acceptée).
Future<Set<String>> mesSuivis(SupabaseClient client, String monId) async {
  final lignes = await client
      .from('abonnements')
      .select('suivi_id')
      .eq('suiveur_id', monId)
      .eq('statut', 'accepte');
  return {for (final l in lignes) l['suivi_id'] as String};
}

/// Condition PostgREST (pour `.or()`) qui limite des souvenirs à « mon
/// réseau » : les miens, ceux des personnes que je suis ([suivis]), et
/// ceux qui m'ont été adressés nommément ou via une Table
/// ("Seulement…"). La RLS laisse aussi lire les posts de tous les profils
/// publics : sans ce filtre, ceux d'inconnus apparaîtraient. Partagée
/// par le Feed et la carte, pour qu'ils montrent exactement le même
/// réseau.
String conditionSouvenirsDuReseau(String monId, Set<String> suivis) {
  final auteurs = [monId, ...suivis];
  return 'auteur_id.in.(${auteurs.join(',')}),visibilite.eq.seulement';
}
