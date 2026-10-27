import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

NotificationTabl _n(
  TypeNotification type,
  String qui,
  DateTime quand, {
  String? souvenir,
  String? restaurant,
  String? texte,
}) => NotificationTabl(
  type: type,
  acteur: (id: qui, pseudo: qui, photoUrl: null),
  creeLe: quand,
  souvenirId: souvenir,
  restaurantNom: restaurant,
  texte: texte,
);

String _phrase(LigneNotification l) =>
    [for (final m in phraseNotification(l)) m.texte].join();

void main() {
  final vues = DateTime(2026, 10, 26, 12);

  test('les demandes à part, les j\'aime d\'un même moment rassemblés', () {
    final r = rangerNotifications([
      _n(
        TypeNotification.reaction,
        'Emma',
        DateTime(2026, 10, 27, 9),
        souvenir: 's1',
        restaurant: 'Bibo',
      ),
      _n(TypeNotification.demandeSuivi, 'Léa', DateTime(2026, 10, 27, 8)),
      _n(
        TypeNotification.reaction,
        'Martin',
        DateTime(2026, 10, 25),
        souvenir: 's1',
        restaurant: 'Bibo',
      ),
      _n(
        TypeNotification.commentaire,
        'Arthur',
        DateTime(2026, 10, 24),
        souvenir: 's1',
        restaurant: 'Bibo',
        texte: 'Trop bon',
      ),
      _n(
        TypeNotification.reaction,
        'Louise',
        DateTime(2026, 10, 20),
        souvenir: 's2',
        restaurant: 'Septime',
      ),
    ], vuesLe: vues);

    expect([for (final d in r.demandes) d.acteur.pseudo], ['Léa']);
    expect(r.autres, hasLength(3));
    final jaime = r.autres.first;
    expect([for (final a in jaime.acteurs) a.pseudo], ['Emma', 'Martin']);
    // Le plus récent fait la ligne nouvelle.
    expect(jaime.nouvelle, isTrue);
    expect(r.autres[1].nouvelle, isFalse);
    expect(_phrase(jaime), 'Emma et Martin ont aimé votre moment chez Bibo.');
  });

  test('les phrases de chaque notification', () {
    LigneNotification ligne(
      TypeNotification type,
      List<String> qui, {
      String? texte,
    }) => LigneNotification(
      type: type,
      acteurs: [for (final q in qui) (id: q, pseudo: q, photoUrl: null)],
      creeLe: DateTime(2026),
      nouvelle: false,
      restaurantNom: 'Bibo',
      texte: texte,
    );
    expect(
      _phrase(ligne(TypeNotification.demandeSuivi, ['Léa'])),
      'Léa souhaite vous suivre.',
    );
    expect(
      _phrase(ligne(TypeNotification.nouvelAbonne, ['Léa'])),
      'Léa vous suit désormais.',
    );
    expect(
      _phrase(ligne(TypeNotification.suiviAccepte, ['Léa'])),
      'Léa a accepté votre demande de suivi.',
    );
    expect(
      _phrase(
        ligne(TypeNotification.reaction, [
          'Emma',
          'Martin',
          'Louise',
          'Arthur',
        ]),
      ),
      'Emma, Martin et 2 autres ont aimé votre moment chez Bibo.',
    );
    expect(
      _phrase(ligne(TypeNotification.commentaire, ['Emma'], texte: 'Trop bon')),
      'Emma a commenté votre moment chez Bibo : « Trop bon »',
    );
    expect(
      _phrase(
        ligne(TypeNotification.demandeAvis, [
          'Martin',
        ], texte: 'Tu me conseilles ?'),
      ),
      'Martin vous demande votre avis chez Bibo : « Tu me conseilles ? »',
    );
    expect(
      _phrase(
        LigneNotification(
          type: TypeNotification.avisRecu,
          acteurs: const [(id: 'e', pseudo: 'Emma', photoUrl: null)],
          creeLe: DateTime(2026),
          nouvelle: false,
          restaurantNom: 'Bibo',
          reponse: ReponseAvis.oui,
          texte: 'La burrata',
        ),
      ),
      'Emma a répondu chez Bibo : 😍 Oui, vas-y — « La burrata »',
    );
    // Les noms en gras.
    expect(
      phraseNotification(ligne(TypeNotification.reaction, ['Emma'])).first,
      (texte: 'Emma', gras: true),
    );
  });

  test('la pastille : au moins une notification depuis la dernière visite', () {
    final n = [_n(TypeNotification.reaction, 'Emma', DateTime(2026, 10, 25))];
    expect(aDesNouvelles(n, vuesLe: vues), isFalse);
    expect(aDesNouvelles(n, vuesLe: DateTime(2026, 10, 1)), isTrue);
    expect(aDesNouvelles(n), isTrue);
    expect(aDesNouvelles([]), isFalse);
  });
}
