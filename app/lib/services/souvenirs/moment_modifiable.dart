import '../restaurants/lieu_restaurant.dart';
import 'audience_souvenir.dart';
import 'emotion.dart';

/// Ce qu'on peut changer d'un moment déjà publié : où, comment c'était,
/// ce qu'on en dit, avec qui, ce qui ressort, la boisson et qui le voit.
/// Ni ses photos ni sa date : c'est ce qui a eu lieu.
class MomentModifiable {
  const MomentModifiable({
    required this.lieu,
    this.emotion,
    this.legende,
    this.amisTaguesIds = const {},
    this.impressions = const [],
    this.boissonTexte,
    this.audience = AudienceSouvenir.toutLeMonde,
  });

  final LieuRestaurant lieu;

  /// `null` pour un moment publié avant qu'on la demande.
  final Emotion? emotion;
  final String? legende;
  final Set<String> amisTaguesIds;
  final List<String> impressions;
  final String? boissonTexte;
  final AudienceSouvenir audience;
}
