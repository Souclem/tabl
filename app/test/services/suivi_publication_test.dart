import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'depot_publication_simule.dart';

/// Un serveur que le test commande : les dépôts de photos et l'ordre de
/// publier attendent son feu vert, et une coupure est une vraie
/// [SocketException] (celle d'un téléphone sans réseau).
class _Serveur extends DepotPublicationSimule {
  Completer<void>? feuVertPhotos;
  Completer<void>? feuVertCommit;
  final commitDemande = Completer<void>();

  /// Les dépôts de photos échouent comme sans réseau.
  bool coupureReseau = false;

  @override
  Future<void> deposerPhoto(String chemin, Uint8List octets) async {
    await feuVertPhotos?.future;
    if (coupureReseau) throw const SocketException('Network is unreachable');
    return super.deposerPhoto(chemin, octets);
  }

  @override
  Future<bool> passerEnPublie(String momentId) async {
    if (!commitDemande.isCompleted) commitDemande.complete();
    await feuVertCommit?.future;
    return super.passerEnPublie(momentId);
  }
}

void main() {
  late Directory racine;
  late _Serveur serveur;
  late BrouillonsLocaux brouillons;
  late FileEnvoi file;
  late EnvoiPublications envois;

  final midi = DateTime(2026, 11, 8, 12, 30);
  const lieu = LieuRestaurant(nom: 'Chez Marcel', ville: 'Liège');

  Future<Brouillon> brouillonPret({AudienceSouvenir? audience}) async {
    var brouillon = await brouillons.ajouterPhoto(
      octets: Uint8List.fromList([1, 2, 3]),
      priseLe: midi,
    );
    brouillon = await brouillons.ajouterPhoto(
      octets: Uint8List.fromList([10, 11, 12]),
      priseLe: midi,
      brouillonId: brouillon.id,
    );
    return (await brouillons.mettreAJour(
      brouillon.id,
      (b) => b.copieAvec(
        lieu: () => lieu,
        emotion: () => Emotion.coupDeCoeur,
        audience: audience,
      ),
    ))!;
  }

  Future<String> brouillonSansLieu() async => (await brouillons.ajouterPhoto(
    octets: Uint8List.fromList([1]),
    priseLe: midi,
  )).id;

  setUp(() {
    racine = Directory.systemTemp.createTempSync('suivi_test');
    serveur = _Serveur();
    brouillons = BrouillonsLocaux(racine, maintenant: () => midi);
    file = FileEnvoi(racine);
    envois = EnvoiPublications(
      serveur,
      brouillons,
      file,
      maintenant: () => midi,
    );
  });

  tearDown(() => racine.deleteSync(recursive: true));

  /// Le temps de l'écran : une image toutes les 16 ms, entre deux tours
  /// d'entrées-sorties réelles, jusqu'à ce que [pret] soit vrai.
  Future<Duration> faireTourner(
    SuiviPublication suivi,
    bool Function() pret, {
    Duration depuis = Duration.zero,
    void Function()? aChaqueImage,
  }) async {
    var t = depuis;
    for (var i = 0; i < 2000 && !pret(); i++) {
      t += const Duration(milliseconds: 16);
      suivi.avancer(t);
      aChaqueImage?.call();
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(pret(), isTrue, reason: 'état jamais atteint : ${suivi.phase}');
    return t;
  }

  /// Avance l'horloge de [secondes] sans attendre la moindre entrée-sortie.
  Duration avancerSec(SuiviPublication suivi, Duration de, int secondes) {
    var t = de;
    for (var i = 0; i < secondes * 62; i++) {
      t += const Duration(milliseconds: 16);
      suivi.avancer(t);
    }
    return t;
  }

  group('progression', () {
    test('suit l\'envoi : plafonnée à 30 % tant que rien n\'est parti, jamais '
        '100 % avant le serveur', () async {
      serveur.feuVertPhotos = Completer<void>();
      final id = (await brouillonPret()).id;
      final suivi = SuiviPublication(envois, id);
      final demarrage = suivi.demarrer();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final t = avancerSec(suivi, Duration.zero, 6);
      expect(suivi.phase, PhaseCloche.envoi);
      expect(suivi.pourcentage, lessThanOrEqualTo(30));
      expect(suivi.pourcentage, greaterThan(20));
      expect(suivi.reseauLent, isTrue);
      // Rien à toucher : ni Modifier ni Annuler.
      expect(suivi.gestes, isEmpty);

      serveur.feuVertPhotos!.complete();
      var precedent = suivi.pourcentage;
      await faireTourner(
        suivi,
        () => suivi.resultat != null,
        depuis: t,
        aChaqueImage: () {
          expect(suivi.pourcentage, greaterThanOrEqualTo(precedent));
          precedent = suivi.pourcentage;
          if (suivi.phase != PhaseCloche.publie) {
            expect(suivi.pourcentage, lessThan(100));
          }
          if (suivi.phase == PhaseCloche.validation) {
            expect(suivi.gestes, isEmpty);
          }
        },
      );
      await demarrage;

      expect(suivi.resultat!.issue, IssueCloche.publie);
      expect(suivi.pourcentage, 100);
      expect(suivi.progression, 1);
      expect(serveur.lignes[id]!['statut'], statutPublie);
    });

    test('avant le premier dépôt, le trait ne dépasse pas 30 %', () async {
      serveur.feuVertPhotos = Completer<void>();
      final id = (await brouillonPret()).id;
      final suivi = SuiviPublication(envois, id);
      final demarrage = suivi.demarrer();

      final t = avancerSec(suivi, Duration.zero, 5);
      expect(suivi.pourcentage, lessThanOrEqualTo(30));

      serveur.feuVertPhotos!.complete();
      await faireTourner(suivi, () => suivi.resultat != null, depuis: t);
      await demarrage;
    });

    test('la validation (90 → 99 %) attend le serveur', () async {
      serveur.feuVertCommit = Completer<void>();
      final id = (await brouillonPret()).id;
      final suivi = SuiviPublication(envois, id);
      final demarrage = suivi.demarrer();
      await serveur.commitDemande.future;

      final t = await faireTourner(
        suivi,
        () => suivi.phase == PhaseCloche.validation,
      );
      final fin = avancerSec(suivi, t, 5);
      expect(suivi.phase, PhaseCloche.validation);
      expect(suivi.pourcentage, inInclusiveRange(90, 99));
      expect(suivi.gestes, isEmpty);
      expect(suivi.reseauLent, isTrue);

      serveur.feuVertCommit!.complete();
      await faireTourner(suivi, () => suivi.resultat != null, depuis: fin);
      await demarrage;
      expect(suivi.resultat!.issue, IssueCloche.publie);
    });
  });

  group('sans réseau', () {
    test('une coupure pendant les photos : « Envoyer dès que possible » met la '
        'publication dans la file', () async {
      serveur.coupureReseau = true;
      final id = (await brouillonPret()).id;
      final suivi = SuiviPublication(envois, id);
      await suivi.demarrer();
      avancerSec(suivi, Duration.zero, 1);

      expect(suivi.phase, PhaseCloche.horsLigne);
      expect(suivi.enAttenteDuChoix, isTrue);
      expect(suivi.gestes, [
        GesteCloche.garderEnBrouillon,
        GesteCloche.envoyerDesQuePossible,
      ]);

      await suivi.envoyerDesQuePossible();

      expect(suivi.resultat!.issue, IssueCloche.enAttente);
      expect((await file.lire(id))!.etat, EtatEnvoi.enAttente);
      expect(await brouillons.charger(id), isNotNull);
      expect(serveur.lignes[id]?['statut'], isNot(statutPublie));
    });

    test('« Garder en brouillon » : rien n\'est envoyé', () async {
      serveur.coupureReseau = true;
      final id = (await brouillonPret()).id;
      final suivi = SuiviPublication(envois, id);
      await suivi.demarrer();

      await suivi.garderEnBrouillon();

      expect(suivi.resultat!.issue, IssueCloche.brouillonGarde);
      expect(await brouillons.charger(id), isNotNull);
      expect(serveur.lignes[id]?['statut'], isNot(statutPublie));
    });

    test('aucune requête n\'aboutit (même la première) : hors ligne', () async {
      serveur.horsLigne = true;
      final id = (await brouillonPret()).id;
      final suivi = SuiviPublication(envois, id);
      await suivi.demarrer();

      expect(suivi.phase, PhaseCloche.horsLigne);
    });
  });

  group('échec', () {
    test('un refus du serveur n\'est pas « pas de réseau » ; « Réessayer » '
        'repart avec le même identifiant', () async {
      serveur.echecAuCommit = true;
      final id = (await brouillonPret()).id;
      final suivi = SuiviPublication(envois, id);
      await suivi.demarrer();
      avancerSec(suivi, Duration.zero, 1);

      expect(suivi.phase, PhaseCloche.echec);
      expect(suivi.gestes, [
        GesteCloche.garderEnBrouillon,
        GesteCloche.reessayer,
      ]);
      expect(serveur.lignes[id]!['statut'], statutBrouillon);

      serveur.echecAuCommit = false;
      final relance = suivi.reessayer();
      expect(suivi.phase, PhaseCloche.envoi);
      expect(suivi.pourcentage, 0);
      await faireTourner(suivi, () => suivi.resultat != null);
      await relance;

      expect(suivi.resultat!.issue, IssueCloche.publie);
      expect(serveur.lignes.keys, [id]);
      expect(serveur.lignes[id]!['statut'], statutPublie);
    });

    test(
      'une photo qui échoue (erreur du serveur) : réessayer ou garder',
      () async {
        serveur.echecAuRang = 1;
        final id = (await brouillonPret()).id;
        final suivi = SuiviPublication(envois, id);
        await suivi.demarrer();

        expect(suivi.phase, PhaseCloche.echec);
        expect(suivi.gestes, [
          GesteCloche.garderEnBrouillon,
          GesteCloche.reessayer,
        ]);

        await suivi.garderEnBrouillon();
        expect(suivi.resultat!.issue, IssueCloche.brouillonGarde);
        expect(serveur.lignes, isEmpty);
        expect(await brouillons.charger(id), isNotNull);
      },
    );

    test('« Réessayer » est refusé hors échec', () async {
      serveur.coupureReseau = true;
      final id = (await brouillonPret()).id;
      final suivi = SuiviPublication(envois, id);
      await suivi.demarrer();
      expect(suivi.phase, PhaseCloche.horsLigne);

      await suivi.reessayer();

      expect(suivi.phase, PhaseCloche.horsLigne);
      expect(suivi.resultat, isNull);
    });

    test('un brouillon sans lieu revient à la finalisation', () async {
      final suivi = SuiviPublication(envois, await brouillonSansLieu());
      await suivi.demarrer();
      expect(suivi.resultat!.issue, IssueCloche.modifier);
    });

    test('un brouillon disparu : annulé', () async {
      final suivi = SuiviPublication(envois, 'inconnu');
      await suivi.demarrer();
      expect(suivi.resultat!.issue, IssueCloche.annule);
    });
  });

  group('moment déjà publié', () {
    test('la relance le trouve publié : la cloche le dit, sans prétendre que '
        'les modifications sont prises', () async {
      final brouillon = await brouillonPret();
      final id = brouillon.id;
      await PublicationEnDeuxTemps(serveur).preparer(
        DemandePublication(
          id: id,
          lieu: lieu,
          photos: [
            for (final p in brouillon.photos)
              brouillons.fichierPhoto(id, p.id).readAsBytesSync(),
          ],
          emotion: Emotion.coupDeCoeur,
          priseLe: midi,
        ),
      );
      serveur.lignes[id]!['statut'] = statutPublie;

      final suivi = SuiviPublication(envois, id);
      final demarrage = suivi.demarrer();
      await faireTourner(suivi, () => suivi.resultat != null);
      await demarrage;

      expect(suivi.dejaPublie, isTrue);
      expect(suivi.resultat!.issue, IssueCloche.dejaPublie);
      expect(suivi.annulationTropTard, isFalse);
    });
  });

  group('Tables', () {
    test('une association échouée est rendue à l\'appelant', () async {
      final id = (await brouillonPret(
        audience: const AudienceSouvenir(
          mode: ModeAudience.seulement,
          tableIds: {'t1', 't2'},
        ),
      )).id;
      serveur.tablesRefusees = {'t2'};
      final suivi = SuiviPublication(envois, id);
      final demarrage = suivi.demarrer();
      await faireTourner(suivi, () => suivi.resultat != null);
      await demarrage;

      expect(suivi.resultat!.issue, IssueCloche.publie);
      expect(suivi.resultat!.tablesEnEchec, ['t2']);
      expect(suivi.tablesEnEchec, ['t2']);
    });
  });

  group('estErreurReseau', () {
    test('les coupures et les délais', () {
      expect(estErreurReseau(const SocketException('x')), isTrue);
      expect(estErreurReseau(TimeoutException('x')), isTrue);
      expect(
        estErreurReseau(Exception('Failed host lookup: supabase.co')),
        isTrue,
      );
    });

    test('un refus ou un bogue n\'est pas une coupure', () {
      expect(estErreurReseau(StateError('refusé')), isFalse);
      expect(estErreurReseau(ArgumentError('x')), isFalse);
    });

    test('ParallelWaitError : coupure dedans, ou non', () async {
      Future<Object> attraper(List<Future<void>> taches) async {
        try {
          await taches.wait;
        } catch (e) {
          return e;
        }
        throw StateError('aucune erreur');
      }

      final coupure = await attraper([
        Future<void>.value(),
        Future<void>.error(const SocketException('x')),
      ]);
      final refus = await attraper([
        Future<void>.error(StateError('403')),
        Future<void>.value(),
      ]);
      expect(coupure, isA<ParallelWaitError<dynamic, dynamic>>());
      expect(estErreurReseau(coupure), isTrue);
      expect(estErreurReseau(refus), isFalse);
    });
  });
}
