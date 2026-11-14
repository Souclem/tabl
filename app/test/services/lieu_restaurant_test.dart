import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

void main() {
  test('description : type en français, adresse, ville et distance', () {
    const lieu = LieuRestaurant(
      nom: 'Le Paris-Brest',
      ville: 'Liège',
      fsqPlaceId: 'x',
      adresse: 'Rue du Pont 16',
      categories: ['French Restaurant'],
      distanceM: 348,
    );
    expect(lieu.description, 'Français · Rue du Pont 16, Liège · 350 m');
  });

  test(
    'description : catégorie inconnue gardée telle quelle, sans adresse',
    () {
      const lieu = LieuRestaurant(
        nom: 'X',
        ville: 'Liège',
        categories: ['Zorglub Place'],
      );
      expect(lieu.description, 'Zorglub Place · Liège');
    },
  );

  test('saisi à la main = ni restaurant Tabl ni lieu de l\'annuaire', () {
    expect(
      const LieuRestaurant.manuel(nom: 'Chez K', ville: 'Liège').estManuel,
      isTrue,
    );
    expect(
      const LieuRestaurant(nom: 'a', ville: 'b', fsqPlaceId: 'f').estManuel,
      isFalse,
    );
  });

  test('normaliserPourRecherche : minuscules et sans accents', () {
    expect(
      normaliserPourRecherche('  ¡Toma! Cuisine Immersive '),
      '!toma! cuisine immersive',
    );
    expect(normaliserPourRecherche('Chez Mémères'), 'chez memeres');
    expect(normaliserPourRecherche('Œuf'), 'oeuf');
  });

  group('hors restaurant', () {
    test('jamais localisé, même lu de la base', () {
      expect(const LieuRestaurant.domicile().personnel, isTrue);
      expect(const LieuRestaurant.domicile().latitude, isNull);
      expect(GenreLieu.depuisBase(null, prive: false), GenreLieu.restaurant);
      expect(GenreLieu.depuisBase('domicile', prive: true), GenreLieu.domicile);
      // Un lieu personnel d'avant les genres est « chez ».
      expect(GenreLieu.depuisBase(null, prive: true), GenreLieu.chez);
      expect(GenreLieu.restaurant.enBase, isNull);
      expect(GenreLieu.ailleurs.enBase, 'ailleurs');
    });

    test(
      '« Chez moi » se lit « Chez vous » pour soi, son pseudo pour les autres',
      () {
        expect(
          libelleLieu(
            genre: GenreLieu.domicile,
            nom: nomDomicile,
            auteurEstMoi: true,
          ),
          'Chez vous',
        );
        expect(
          libelleLieu(
            genre: GenreLieu.domicile,
            nom: nomDomicile,
            auteurPseudo: 'Léa',
          ),
          'Chez Léa',
        );
      },
    );

    test('chez une personne de Tabl : son pseudo, « Chez vous » pour elle', () {
      expect(
        libelleLieu(
          genre: GenreLieu.chez,
          nom: nomChezQuelquun,
          hotePseudo: 'emma',
        ),
        'Chez emma',
      );
      expect(
        libelleLieu(
          genre: GenreLieu.chez,
          nom: nomChezQuelquun,
          hotePseudo: 'emma',
          hoteEstMoi: true,
        ),
        'Chez vous',
      );
      // Elle a retiré son nom.
      expect(
        libelleLieu(genre: GenreLieu.chez, nom: nomChezQuelquun),
        'Chez quelqu\'un',
      );
      expect(
        libelleLieu(genre: GenreLieu.ailleurs, nom: 'Pique-nique'),
        'Pique-nique',
      );
    });

    test(
      'dans une phrase : « chez Bibo », « chez vous », rien pour un pique-nique',
      () {
        expect(chezDansUnePhrase('Bibo', null), 'chez Bibo');
        expect(chezDansUnePhrase('Chez moi', 'domicile'), 'chez vous');
        expect(chezDansUnePhrase('Chez Mamie', 'chez'), 'chez Mamie');
        expect(chezDansUnePhrase('Chez Léon', null), 'chez Léon');
        expect(chezDansUnePhrase('Pique-nique', 'ailleurs'), isNull);
        expect(chezDansUnePhrase(null, null), isNull);
      },
    );

    test('« Chez… » écrit à la main : un nom, jamais « Chez chez »', () {
      final mamie = lieuPersonnelSaisi('mamie', GenreLieu.chez);
      expect(mamie.lieu!.nom, 'Chez mamie');
      expect(
        lieuPersonnelSaisi('chez Mamie', GenreLieu.chez).lieu!.nom,
        'Chez Mamie',
      );
      expect(
        lieuPersonnelSaisi('chez ', GenreLieu.chez).erreur,
        'Donnez-lui un nom.',
      );
      expect(
        lieuPersonnelSaisi('x' * 61, GenreLieu.ailleurs).erreur,
        '60 caractères au plus.',
      );
      final lac = lieuPersonnelSaisi(
        ' Au bord du lac ',
        GenreLieu.ailleurs,
      ).lieu!;
      expect(lac.nom, 'Au bord du lac');
      expect(lac.genre, GenreLieu.ailleurs);
    });

    test('le même nom qu\'un de mes lieux : c\'est lui', () {
      const mamie = LieuRestaurant.personnel(
        nom: 'Chez Mamie',
        restaurantId: 'r9',
      );
      expect(
        lieuPersonnelSaisi(
          'mamie',
          GenreLieu.chez,
          mesLieux: [mamie],
        ).lieu!.restaurantId,
        'r9',
      );
      // Un autre genre n'est pas le même lieu.
      expect(
        lieuPersonnelSaisi(
          'Chez Mamie',
          GenreLieu.ailleurs,
          mesLieux: [mamie],
        ).lieu!.restaurantId,
        isNull,
      );
    });

    test('« Chez moi » enregistré ou non : le même lieu', () {
      expect(
        const LieuRestaurant.domicile(restaurantId: 'r1').cle,
        const LieuRestaurant.domicile().cle,
      );
      expect(
        const LieuRestaurant.chezQuelquun(
          hoteId: 'emma',
          hotePseudo: 'emma',
        ).cle,
        isNot(
          const LieuRestaurant.chezQuelquun(
            hoteId: 'zoe',
            hotePseudo: 'zoe',
          ).cle,
        ),
      );
    });
  });
}
