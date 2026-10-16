import 'package:flutter/material.dart';
import 'package:app/widgets/widgets.dart';

/// Planche d'états DEV de l'Explorer (megaprompt Bloc 1, règles 77-78) :
/// vérifie que les objets cartographiques restent visuellement
/// distincts, et sert de référence rapide sans avoir à reproduire
/// chaque combinaison de données réelles. Accessible uniquement en
/// debug (voir le bouton dans `EcranExplorer`), jamais montrée en
/// production.
class EcranExplorerDev extends StatelessWidget {
  const EcranExplorerDev({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablTokens.fond,
      appBar: AppBar(
        backgroundColor: TablTokens.fond,
        title: const Text('Explorer — états DEV', style: TablTokens.titre),
      ),
      body: ListView(
        padding: const EdgeInsets.all(TablTokens.espaceM),
        children: [
          _section('Grammaire visuelle — 4 objets distincts', [
            _ligneMarqueurs('Restaurant small / medium / large', [
              const TablMarqueurRestaurant(
                diametre: 14,
                selectionne: false,
                connuUniquementReseauEtendu: false,
                aDeLaRecurrence: false,
                libelleAccessibilite: 'small',
                onTap: _rienFaire,
              ),
              const TablMarqueurRestaurant(
                diametre: 20,
                selectionne: false,
                connuUniquementReseauEtendu: false,
                aDeLaRecurrence: false,
                libelleAccessibilite: 'medium',
                onTap: _rienFaire,
              ),
              const TablMarqueurRestaurant(
                diametre: 28,
                selectionne: false,
                connuUniquementReseauEtendu: false,
                aDeLaRecurrence: false,
                libelleAccessibilite: 'large',
                onTap: _rienFaire,
              ),
            ]),
            _ligneMarqueurs('Récurrence / sélectionné / réseau étendu seul', [
              const TablMarqueurRestaurant(
                diametre: 20,
                selectionne: false,
                connuUniquementReseauEtendu: false,
                aDeLaRecurrence: true,
                libelleAccessibilite: 'récurrence',
                onTap: _rienFaire,
              ),
              const TablMarqueurRestaurant(
                diametre: 20,
                selectionne: true,
                connuUniquementReseauEtendu: false,
                aDeLaRecurrence: false,
                libelleAccessibilite: 'sélectionné',
                onTap: _rienFaire,
              ),
              const TablMarqueurRestaurant(
                diametre: 20,
                selectionne: false,
                connuUniquementReseauEtendu: true,
                aDeLaRecurrence: false,
                libelleAccessibilite: 'réseau étendu seul',
                onTap: _rienFaire,
              ),
            ]),
            _ligneMarqueurs('Cluster / agrégat de ville / position utilisateur', [
              TablMarqueurCluster(nombreRestaurants: 5, onTap: _rienFaire),
              TablMarqueurAgregatVille(
                ville: 'Paris',
                nombreRestaurants: 47,
                onTap: _rienFaire,
              ),
              const TablMarqueurPositionUtilisateur(precisionFaible: false),
              const TablMarqueurPositionUtilisateur(precisionFaible: true),
            ]),
          ]),
          _section('Réseau — FREE vs PREMIUM', [
            const Text('MAP01 Free / Mes proches', style: TablTokens.legende),
            const Text('MAP02 Free / Réseau étendu 🔒', style: TablTokens.legende),
            const Text('MAP03 Premium / Mes proches', style: TablTokens.legende),
            const Text('MAP04 Premium / Réseau étendu', style: TablTokens.legende),
            const Text('MAP05 Premium / Les deux', style: TablTokens.legende),
          ]),
          _section('Liste', [
            const TablLigneListeCercle(
              nom: 'Septime',
              sousTitreLieu: 'Paris 11e',
              procheDirectResume: 'Emma, Thomas +2 connaissent cette adresse',
              recurrenceResume: '★ Ils y retournent',
              onTap: _rienFaire,
            ),
          ]),
          _section('Zone vide (règle 48)', const [
            Text('« Peu d\'adresses de vos proches ici. »', style: TablTokens.corps),
          ]),
        ],
      ),
    );
  }

  Widget _section(String titre, List<Widget> enfants) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TablTokens.espaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: TablTokens.sousTitre),
          const SizedBox(height: TablTokens.espaceM),
          ...enfants,
        ],
      ),
    );
  }

  Widget _ligneMarqueurs(String legende, List<Widget> marqueurs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TablTokens.espaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(legende, style: TablTokens.legende),
          const SizedBox(height: TablTokens.espaceS),
          Row(children: [for (final m in marqueurs) Padding(
            padding: const EdgeInsets.only(right: TablTokens.espaceM),
            child: m,
          )]),
        ],
      ),
    );
  }
}

void _rienFaire() {}
