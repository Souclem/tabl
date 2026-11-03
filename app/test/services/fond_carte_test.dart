import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

void main() {
  test('terres, frontières et routes, en coordonnées du ciel', () {
    final fond = fondCarteDepuisJson(
      terres: '[[557,5064,600,5100,520,5100]]',
      frontieres: '[[400,5000,410,5010]]',
      // Une autoroute dès le zoom 5 : (5,570 ; 50,640) puis +0,010 ; +0,002.
      routes: '[[5,1,[[5570,50640,10,2]]]]',
    );

    final terre = fond.terres.single;
    expect(terre.points[0], closeTo(5.57, 1e-9));
    expect(terre.points[1], closeTo(mercY(50.64), 1e-9));
    expect(terre.xmin, closeTo(5.2, 1e-9));
    expect(terre.xmax, closeTo(6.0, 1e-9));
    expect(fond.frontieres.single.points, hasLength(4));

    final niveau = fond.routes.single;
    expect(niveau.zoom, 5);
    expect(niveau.autoroute, isTrue);
    expect(niveau.traces.single.points[2], closeTo(5.58, 1e-9));
    expect(niveau.traces.single.points[3], closeTo(mercY(50.642), 1e-9));
  });

  test('un pays à cheval sur la ligne de changement de date reste d\'un '
      'seul tenant', () {
    final fond = fondCarteDepuisJson(
      terres: '[[17900,6500,-17900,6500]]',
      frontieres: '[]',
      routes: '[]',
    );

    // -179° devient 181° : à côté de 179°, pas à l'autre bout du monde.
    expect(fond.terres.single.points[2], closeTo(181, 1e-9));
  });
}
