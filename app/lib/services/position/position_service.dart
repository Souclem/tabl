/// Une position GPS.
typedef Coordonnees = ({double latitude, double longitude});

/// La position du téléphone, quand l'utilisateur l'autorise. Jamais
/// bloquant : sans autorisation ou sans signal, on renvoie `null` et
/// l'écran fait sans (pas de tri par proximité, carte non centrée).
abstract interface class PositionService {
  Future<Coordonnees?> positionActuelle();
}
