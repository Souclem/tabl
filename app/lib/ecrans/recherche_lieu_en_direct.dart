import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Une position qui ne bouge pas : celle des photos (ou du téléphone au
/// moment d'ouvrir), pour trier la recherche autour d'elle.
class PositionFixe implements PositionService {
  const PositionFixe(this.position);

  final Coordonnees position;

  @override
  Future<Coordonnees?> positionActuelle() async => position;
}

/// La recherche d'un restaurant au fil de la frappe, partagée par les
/// écrans où l'on choisit un lieu (publier un moment, ajouter un
/// souvenir) : quelques lettres suffisent, la réponse arrive triée par
/// proximité dès que la position est connue.
mixin RechercheLieuEnDirect<T extends StatefulWidget> on State<T> {
  /// `null` : pas de recherche dans l'annuaire.
  RechercheLieuService? get rechercheLieuService;

  /// `null` : suggestions non triées par proximité.
  PositionService? get positionService;

  final recherche = TextEditingController();
  Timer? _attenteRecherche;
  List<LieuRestaurant> suggestions = const [];
  bool rechercheEnCours = false;

  /// La position du téléphone, `null` tant qu'elle n'est pas connue.
  Coordonnees? position;

  @override
  void initState() {
    super.initState();
    _localiser();
  }

  @override
  void dispose() {
    _attenteRecherche?.cancel();
    recherche.dispose();
    super.dispose();
  }

  Future<void> _localiser() async {
    final trouvee = await positionService?.positionActuelle();
    if (!mounted || trouvee == null) return;
    setState(() => position = trouvee);
    // Une recherche tapée avant que la position n'arrive est relancée
    // pour profiter du tri par proximité.
    if (recherche.text.trim().length >= 2) _rechercher(recherche.text);
  }

  void rechercherAvecAttente(String texte) {
    _attenteRecherche?.cancel();
    _attenteRecherche = Timer(
      const Duration(milliseconds: 250),
      () => _rechercher(texte),
    );
  }

  Future<void> _rechercher(String texte) async {
    final service = rechercheLieuService;
    if (service == null) return;
    if (texte.trim().length < 2) {
      setState(() => suggestions = const []);
      return;
    }
    setState(() => rechercheEnCours = true);
    try {
      final resultats = await service.rechercher(
        texte,
        latitude: position?.latitude,
        longitude: position?.longitude,
      );
      // Une réponse plus ancienne que la frappe actuelle est ignorée.
      if (!mounted || recherche.text != texte) return;
      setState(() => suggestions = resultats);
    } catch (e) {
      debugPrint('RechercheLieuEnDirect: $e');
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => rechercheEnCours = false);
    }
  }
}
