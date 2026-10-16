import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Cover ou mosaïque d'une Table (megaprompt Bloc 3, règles 11-16).
///
/// Composant pur : ne sait pas si [urls] vient d'une cover manuelle ou
/// d'une mosaïque générée — c'est déjà tranché par l'appelant (règle 11 :
/// cover manuelle > mosaïque vivante > atmosphère subtile). Reçoit
/// directement la liste déjà réduite à afficher (0 à 6 éléments — le
/// tri à "4 à 6 images fortes" au-delà de 6 se fait côté service, pas
/// ici), jamais de logique de sélection ou de tirage aléatoire dans ce
/// widget.
class TablCouvertureTable extends StatelessWidget {
  const TablCouvertureTable({
    super.key,
    required this.urls,
    this.arrondi = TablTokens.arrondiM,
  });

  final List<String> urls;
  final double arrondi;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(arrondi),
      child: switch (urls.length) {
        0 => _fallback(),
        1 => _photo(urls[0]),
        2 => _split(urls, const [0.5, 0.5]),
        3 => _troisPhotos(urls),
        _ => _mosaiqueEditoriale(urls.take(6).toList()),
      },
    );
  }

  Widget _fallback() {
    return Container(
      color: TablTokens.surface,
      alignment: Alignment.center,
      child: const Icon(
        Icons.table_restaurant_outlined,
        color: TablTokens.texteDoux,
      ),
    );
  }

  Widget _photo(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => _fallback(),
    );
  }

  Widget _split(List<String> urls, List<double> proportions) {
    return Row(
      children: [
        for (var i = 0; i < urls.length; i++)
          Expanded(flex: (proportions[i] * 10).round(), child: _photo(urls[i])),
      ],
    );
  }

  Widget _troisPhotos(List<String> urls) {
    return Row(
      children: [
        Expanded(flex: 3, child: _photo(urls[0])),
        const SizedBox(width: 2),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(child: _photo(urls[1])),
              const SizedBox(height: 2),
              Expanded(child: _photo(urls[2])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mosaiqueEditoriale(List<String> urls) {
    return GridView.count(
      crossAxisCount: 3,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      children: [for (final url in urls) _photo(url)],
    );
  }
}
