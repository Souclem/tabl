import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/services/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'depot_publication_simule.dart';

/// Un serveur dont le dépôt des photos attend le feu vert du test : de quoi
/// annuler « pendant l'envoi ».
class _DepotLent extends DepotPublicationSimule {
  final feuVert = Completer<void>();
  final depotCommence = Completer<void>();

  @override
  Future<void> deposerPhoto(String chemin, Uint8List octets) async {
    if (!depotCommence.isCompleted) depotCommence.complete();
    await feuVert.future;
    return super.deposerPhoto(chemin, octets);
  }
}

void main() {
  late Directory racine;
  late DateTime maintenant;
  late DepotPublicationSimule depot;
  var compteur = 0;

  final midi = DateTime(2026, 11, 8, 12, 30);
  Uint8List octets(int n) => Uint8List.fromList([n, n + 1, n + 2]);

  /// L'app qui s'ouvre : tout est relu depuis le dossier du téléphone, comme
  /// après une fermeture.
  ({BrouillonsLocaux brouillons, FileEnvoi file, EnvoiPublications envois})
  ouvrirApp([DepotPublicationSimule? serveur]) {
    final brouillons = BrouillonsLocaux(
      racine,
      maintenant: () => maintenant,
      genererId: () => 'id${++compteur}',
    );
    final file = FileEnvoi(racine);
    return (
      brouillons: brouillons,
      file: file,
      envois: EnvoiPublications(
        serveur ?? depot,
        brouillons,
        file,
        maintenant: () => maintenant,
      ),
    );
  }

  /// Un brouillon complet (lieu, émotion) de [photos] photos.
  Future<Brouillon> brouillonPret(
    BrouillonsLocaux brouillons, {
    int photos = 2,
    bool complet = true,
  }) async {
    var brouillon = await brouillons.ajouterPhoto(
      octets: octets(0),
      priseLe: midi,
    );
    for (var i = 1; i < photos; i++) {
      brouillon = await brouillons.ajouterPhoto(
        octets: octets(i * 10),
        priseLe: midi,
        brouillonId: brouillon.id,
      );
    }
    if (!complet) return brouillon;
    return (await brouillons.mettreAJour(
      brouillon.id,
      (b) => b.copieAvec(
        lieu: () => const LieuRestaurant(nom: 'Chez Marcel', ville: 'Liège'),
        emotion: () => Emotion.coupDeCoeur,
        legende: () => 'Une belle table',
      ),
    ))!;
  }

  /// Ce que l'app a laissé sur le téléphone si elle a été fermée avec cet
  /// envoi à cet état.
  Future<void> laisserEnvoi(
    FileEnvoi file,
    String id,
    EtatEnvoi etat, {
    bool commitLance = false,
    String auteur = 'auteur-1',
  }) => file.ecrire(
    EnvoiPublication(
      brouillonId: id,
      auteurId: auteur,
      etat: etat,
      creeLe: maintenant,
      commitLance: commitLance,
    ),
  );

  /// L'étape 1 déjà faite sur le serveur (photos et ligne `brouillon`).
  Future<void> preparerSurServeur(Brouillon b, BrouillonsLocaux brouillons) =>
      PublicationEnDeuxTemps(depot).preparer(
        DemandePublication(
          id: b.id,
          lieu: const LieuRestaurant(nom: 'Chez Marcel', ville: 'Liège'),
          photos: [
            for (final p in b.photos)
              brouillons.fichierPhoto(b.id, p.id).readAsBytesSync(),
          ],
          emotion: Emotion.coupDeCoeur,
          priseLe: b.priseLe,
        ),
      );

  setUp(() {
    racine = Directory.systemTemp.createTempSync('envois_test');
    maintenant = DateTime(2026, 11, 8, 13);
    depot = DepotPublicationSimule();
    compteur = 0;
  });

  tearDown(() => racine.deleteSync(recursive: true));

  group('envoyer (la cloche)', () {
    test('publie, puis le brouillon local et la file l\'oublient', () async {
      final app = ouvrirApp();
      final brouillon = await brouillonPret(app.brouillons);
      final progression = <(int, int)>[];

      final resultat = await app.envois.envoyer(
        brouillon.id,
        surProgression: (e, t) => progression.add((e, t)),
      );

      expect(resultat.statut, StatutEnvoi.publie);
      expect(depot.lignes[brouillon.id]!['statut'], statutPublie);
      expect(progression.last, (2, 2));
      expect(await app.brouillons.charger(brouillon.id), isNull);
      expect(await app.file.lister(), isEmpty);
    });

    test('la file est écrite avant le premier envoi', () async {
      final serveur = _DepotLent();
      final app = ouvrirApp(serveur);
      final brouillon = await brouillonPret(app.brouillons);

      final envoi = app.envois.envoyer(brouillon.id);
      await serveur.depotCommence.future;

      final ligne = await app.file.lire(brouillon.id);
      expect(ligne!.etat, EtatEnvoi.enCours);
      expect(ligne.commitLance, isFalse);
      expect(ligne.auteurId, 'auteur-1');
      serveur.feuVert.complete();
      expect((await envoi).statut, StatutEnvoi.publie);
    });

    test(
      'un échec garde le brouillon et attend le choix de l\'auteur',
      () async {
        final app = ouvrirApp();
        final brouillon = await brouillonPret(app.brouillons);
        depot.echecAuRang = 1;

        final resultat = await app.envois.envoyer(brouillon.id);

        expect(resultat.statut, StatutEnvoi.echec);
        expect(resultat.erreur, isNotNull);
        expect(await app.brouillons.charger(brouillon.id), isNotNull);
        final ligne = (await app.file.lire(brouillon.id))!;
        expect(ligne.etat, EtatEnvoi.echec);
        expect(ligne.derniereErreur, contains('réseau coupé'));
        expect(depot.lignes[brouillon.id]?['statut'], isNot(statutPublie));
      },
    );

    test('« Réessayer » reprend avec le même id, sans doublon', () async {
      final app = ouvrirApp();
      final brouillon = await brouillonPret(app.brouillons);
      depot.echecAuRang = 1;
      await app.envois.envoyer(brouillon.id);
      depot.echecAuRang = null;

      final resultat = await app.envois.envoyer(brouillon.id);

      expect(resultat.statut, StatutEnvoi.publie);
      expect(depot.lignes.keys, [brouillon.id]);
      expect(depot.lignes[brouillon.id]!['statut'], statutPublie);
      expect((await app.file.lister()), isEmpty);
    });

    test('un moment que le serveur a déjà publié le dit au résultat', () async {
      final app = ouvrirApp();
      final brouillon = await brouillonPret(app.brouillons);
      await preparerSurServeur(brouillon, app.brouillons);
      depot.lignes[brouillon.id]!['statut'] = statutPublie;

      final resultat = await app.envois.envoyer(brouillon.id);

      expect(resultat.statut, StatutEnvoi.publie);
      expect(resultat.dejaPublie, isTrue);
      expect(await app.brouillons.charger(brouillon.id), isNull);
    });

    test('un envoi normal n\'est pas « déjà publié »', () async {
      final app = ouvrirApp();
      final brouillon = await brouillonPret(app.brouillons);

      final resultat = await app.envois.envoyer(brouillon.id);

      expect(resultat.dejaPublie, isFalse);
    });

    test('deux envois simultanés du même brouillon : un seul part', () async {
      final serveur = _DepotLent();
      final app = ouvrirApp(serveur);
      final brouillon = await brouillonPret(app.brouillons);

      final premier = app.envois.envoyer(brouillon.id);
      await serveur.depotCommence.future;
      final second = await app.envois.envoyer(brouillon.id);
      serveur.feuVert.complete();

      expect(second.statut, StatutEnvoi.dejaEnCours);
      expect((await premier).statut, StatutEnvoi.publie);
      expect(serveur.appels.where((a) => a == 'commit'), hasLength(1));
    });

    test('un brouillon sans lieu ou sans émotion ne part pas', () async {
      final app = ouvrirApp();
      final brouillon = await brouillonPret(app.brouillons, complet: false);

      final resultat = await app.envois.envoyer(brouillon.id);

      expect(resultat.statut, StatutEnvoi.incomplet);
      expect(depot.appels, isEmpty);
      expect(await app.file.lister(), isEmpty);
    });

    test('un brouillon disparu : introuvable', () async {
      final app = ouvrirApp();
      final resultat = await app.envois.envoyer('inconnu');
      expect(resultat.statut, StatutEnvoi.introuvable);
    });
  });

  group('commit sans doublon', () {
    test(
      'réponse du commit perdue : « Réessayer » ne publie pas deux fois',
      () async {
        final app = ouvrirApp();
        final brouillon = await brouillonPret(app.brouillons);
        depot.reponsePerdueAuCommit = true;

        final perdu = await app.envois.envoyer(brouillon.id);

        expect(perdu.statut, StatutEnvoi.echec);
        expect(depot.lignes[brouillon.id]!['statut'], statutPublie);
        final ligne = (await app.file.lire(brouillon.id))!;
        expect(ligne.etat, EtatEnvoi.echec);
        expect(ligne.commitLance, isTrue);

        depot.reponsePerdueAuCommit = false;
        depot.appels.clear();
        final resultat = await app.envois.envoyer(brouillon.id);

        expect(resultat.statut, StatutEnvoi.publie);
        expect(depot.lignes, hasLength(1));
        expect(depot.appels, isNot(contains('creer')));
        expect(depot.appels, isNot(contains('commit')));
        expect(depot.appels.where((a) => a.startsWith('depot')), isEmpty);
        expect(await app.brouillons.charger(brouillon.id), isNull);
        expect(await app.file.lister(), isEmpty);
      },
    );

    test(
      'réponse perdue puis app fermée : à l\'ouverture, déjà publié',
      () async {
        var app = ouvrirApp();
        final brouillon = await brouillonPret(app.brouillons);
        depot.reponsePerdueAuCommit = true;
        await app.envois.envoyer(brouillon.id);
        depot.reponsePerdueAuCommit = false;
        depot.appels.clear();

        app = ouvrirApp();
        final resultats = await app.envois.reprendre(auLancement: true);

        expect(resultats.map((r) => r.issue), [IssueReprise.publiee]);
        expect(resultats.single.brouillonId, brouillon.id);
        expect(depot.lignes, hasLength(1));
        expect(depot.lignes[brouillon.id]!['statut'], statutPublie);
        expect(depot.appels, isEmpty);
        expect(await app.brouillons.charger(brouillon.id), isNull);
        expect(await app.file.lister(), isEmpty);
      },
    );

    test(
      'app fermée après l\'ordre de publier : le commit est mené à terme',
      () async {
        var app = ouvrirApp();
        final brouillon = await brouillonPret(app.brouillons);
        await preparerSurServeur(brouillon, app.brouillons);
        await laisserEnvoi(
          app.file,
          brouillon.id,
          EtatEnvoi.enCours,
          commitLance: true,
        );
        depot.appels.clear();

        app = ouvrirApp();
        final resultats = await app.envois.reprendre(auLancement: true);

        expect(resultats.map((r) => r.issue), [IssueReprise.publiee]);
        expect(depot.lignes[brouillon.id]!['statut'], statutPublie);
        expect(depot.lignes, hasLength(1));
        expect(depot.appels, ['commit']);
        expect(await app.brouillons.charger(brouillon.id), isNull);
        expect(await app.file.lister(), isEmpty);
      },
    );

    test(
      'publié puis supprimé par son auteur : on n\'en refait rien',
      () async {
        final app = ouvrirApp();
        final brouillon = await brouillonPret(app.brouillons);
        await laisserEnvoi(
          app.file,
          brouillon.id,
          EtatEnvoi.enCours,
          commitLance: true,
        );

        final resultats = await app.envois.reprendre(auLancement: true);

        expect(resultats, isEmpty);
        expect(depot.lignes, isEmpty);
        expect(depot.appels, isEmpty);
        expect(await app.brouillons.charger(brouillon.id), isNull);
        expect(await app.file.lister(), isEmpty);
      },
    );
  });

  group('reprise après fermeture', () {
    test(
      'fermée avant le commit : rien n\'est envoyé, brouillon gardé',
      () async {
        var app = ouvrirApp();
        final brouillon = await brouillonPret(app.brouillons);
        await preparerSurServeur(brouillon, app.brouillons);
        await laisserEnvoi(app.file, brouillon.id, EtatEnvoi.enCours);

        app = ouvrirApp();
        final resultats = await app.envois.reprendre(auLancement: true);

        expect(resultats.map((r) => r.issue), [IssueReprise.interrompue]);
        expect(depot.lignes, isEmpty);
        expect(depot.fichiers, isEmpty);
        expect(await app.brouillons.charger(brouillon.id), isNotNull);
        expect(await app.file.lister(), isEmpty);
      },
    );

    test(
      'fermée avant le commit, hors ligne : la ligne attend le réseau',
      () async {
        var app = ouvrirApp();
        final brouillon = await brouillonPret(app.brouillons);
        await preparerSurServeur(brouillon, app.brouillons);
        await laisserEnvoi(app.file, brouillon.id, EtatEnvoi.enCours);
        depot.horsLigne = true;

        app = ouvrirApp();
        expect(await app.envois.reprendre(auLancement: true), isEmpty);
        expect(await app.file.lister(), hasLength(1));

        depot.horsLigne = false;
        app = ouvrirApp();
        final resultats = await app.envois.reprendre(auLancement: true);
        expect(resultats.map((r) => r.issue), [IssueReprise.interrompue]);
        expect(depot.lignes, isEmpty);
      },
    );

    test('à la reprise (même session), la cloche garde la main', () async {
      final app = ouvrirApp();
      final brouillon = await brouillonPret(app.brouillons);
      await preparerSurServeur(brouillon, app.brouillons);
      await laisserEnvoi(app.file, brouillon.id, EtatEnvoi.enCours);
      await laisserEnvoi(app.file, 'autre', EtatEnvoi.echec);

      final resultats = await app.envois.reprendre();

      expect(resultats, isEmpty);
      expect(depot.lignes[brouillon.id]!['statut'], statutBrouillon);
      expect(await app.file.lister(), hasLength(2));
    });

    test(
      'après un échec déjà vu, l\'ouverture nettoie sans rien annoncer',
      () async {
        var app = ouvrirApp();
        final brouillon = await brouillonPret(app.brouillons);
        depot.echecAuRang = 1;
        await app.envois.envoyer(brouillon.id);
        depot.echecAuRang = null;

        app = ouvrirApp();
        final resultats = await app.envois.reprendre(auLancement: true);

        expect(resultats, isEmpty);
        expect(depot.lignes, isEmpty);
        expect(depot.fichiers, isEmpty);
        expect(await app.brouillons.charger(brouillon.id), isNotNull);
        expect(await app.file.lister(), isEmpty);
      },
    );

    test('« Envoyer dès que possible » : repart à l\'ouverture', () async {
      var app = ouvrirApp();
      final brouillon = await brouillonPret(app.brouillons);
      depot.horsLigne = true;
      expect(
        (await app.envois.envoyer(brouillon.id)).statut,
        StatutEnvoi.echec,
      );
      expect(await app.envois.mettreEnAttente(brouillon.id), isTrue);
      expect((await app.envois.enAttenteDEnvoi()).map((e) => e.brouillonId), [
        brouillon.id,
      ]);

      // Hors ligne à l'ouverture : toujours en attente.
      app = ouvrirApp();
      expect(await app.envois.reprendre(auLancement: true), isEmpty);
      expect(await app.envois.enAttenteDEnvoi(), hasLength(1));
      expect(await app.brouillons.charger(brouillon.id), isNotNull);

      // Le réseau est revenu.
      depot.horsLigne = false;
      app = ouvrirApp();
      final resultats = await app.envois.reprendre(auLancement: true);

      expect(resultats.map((r) => r.issue), [IssueReprise.publiee]);
      expect(depot.lignes[brouillon.id]!['statut'], statutPublie);
      expect(depot.lignes, hasLength(1));
      expect(await app.brouillons.charger(brouillon.id), isNull);
      expect(await app.envois.enAttenteDEnvoi(), isEmpty);
    });

    test('à la reprise de l\'app, la file en attente repart', () async {
      final app = ouvrirApp();
      final brouillon = await brouillonPret(app.brouillons);
      await app.envois.mettreEnAttente(brouillon.id);

      final resultats = await app.envois.reprendre();

      expect(resultats.map((r) => r.issue), [IssueReprise.publiee]);
      expect(depot.lignes[brouillon.id]!['statut'], statutPublie);
    });

    test(
      'envoi en attente, commit passé mais réponse perdue : sans doublon',
      () async {
        var app = ouvrirApp();
        final brouillon = await brouillonPret(app.brouillons);
        depot.reponsePerdueAuCommit = true;
        await app.envois.envoyer(brouillon.id);
        await app.envois.mettreEnAttente(brouillon.id);
        depot.reponsePerdueAuCommit = false;
        depot.appels.clear();

        app = ouvrirApp();
        final resultats = await app.envois.reprendre(auLancement: true);

        expect(resultats.map((r) => r.issue), [IssueReprise.publiee]);
        expect(depot.lignes, hasLength(1));
        expect(depot.appels, isEmpty);
      },
    );

    test(
      'le résultat reste à montrer jusqu\'à ce qu\'on l\'acquitte',
      () async {
        final app = ouvrirApp();
        final brouillon = await brouillonPret(app.brouillons);
        await app.envois.mettreEnAttente(brouillon.id);

        final resultats = await app.envois.reprendre();

        expect(app.envois.aMontrer.value, resultats);
        app.envois.acquitter(resultats.single);
        expect(app.envois.aMontrer.value, isEmpty);
      },
    );

    test('une file d\'un autre compte n\'est pas envoyée', () async {
      final app = ouvrirApp();
      final brouillon = await brouillonPret(app.brouillons);
      await laisserEnvoi(
        app.file,
        brouillon.id,
        EtatEnvoi.enAttente,
        auteur: 'auteur-2',
      );

      expect(await app.envois.reprendre(auLancement: true), isEmpty);
      expect(depot.appels, isEmpty);
      expect(await app.file.lister(), hasLength(1));
      expect(await app.envois.enAttenteDEnvoi(), isEmpty);
    });

    test('sans session, rien ne bouge', () async {
      final app = ouvrirApp();
      final brouillon = await brouillonPret(app.brouillons);
      await app.envois.mettreEnAttente(brouillon.id);
      depot.connecte = false;

      expect(await app.envois.reprendre(auLancement: true), isEmpty);
      expect(depot.appels, isEmpty);
      expect(await app.file.lister(), hasLength(1));
    });

    test('deux reprises simultanées : un seul traitement', () async {
      final app = ouvrirApp();
      final brouillon = await brouillonPret(app.brouillons);
      await app.envois.mettreEnAttente(brouillon.id);

      await Future.wait([app.envois.reprendre(), app.envois.reprendre()]);

      expect(depot.appels.where((a) => a == 'commit'), hasLength(1));
      expect(depot.appels.where((a) => a == 'creer'), hasLength(1));
    });

    test(
      'brouillon local disparu : la ligne et le serveur sont nettoyés',
      () async {
        final app = ouvrirApp();
        final brouillon = await brouillonPret(app.brouillons);
        await preparerSurServeur(brouillon, app.brouillons);
        await app.envois.mettreEnAttente(brouillon.id);
        await app.brouillons.supprimerBrouillon(brouillon.id);

        final resultats = await app.envois.reprendre();

        expect(resultats, isEmpty);
        expect(depot.lignes, isEmpty);
        expect(depot.fichiers, isEmpty);
        expect(await app.file.lister(), isEmpty);
      },
    );
  });

  group('lignes brouillon orphelines du serveur', () {
    test(
      'une ligne que rien ne réclame est supprimée avec ses photos',
      () async {
        final app = ouvrirApp();
        final brouillon = await brouillonPret(app.brouillons);
        await preparerSurServeur(brouillon, app.brouillons);
        depot.lignes[brouillon.id]!['cree_le'] = maintenant.subtract(
          const Duration(hours: 25),
        );

        await app.envois.reprendre(auLancement: true);

        expect(depot.lignes, isEmpty);
        expect(depot.fichiers, isEmpty);
        expect(await app.brouillons.charger(brouillon.id), isNotNull);
      },
    );

    test(
      'trop récente (autre téléphone en train de publier) : gardée',
      () async {
        final app = ouvrirApp();
        final brouillon = await brouillonPret(app.brouillons);
        await preparerSurServeur(brouillon, app.brouillons);
        depot.lignes[brouillon.id]!['cree_le'] = maintenant.subtract(
          const Duration(hours: 1),
        );

        await app.envois.reprendre(auLancement: true);

        expect(depot.lignes, hasLength(1));
      },
    );

    test('une ligne que la file réclame n\'est pas touchée', () async {
      final app = ouvrirApp();
      final brouillon = await brouillonPret(app.brouillons);
      await preparerSurServeur(brouillon, app.brouillons);
      depot.lignes[brouillon.id]!['cree_le'] = maintenant.subtract(
        const Duration(days: 3),
      );
      await laisserEnvoi(app.file, brouillon.id, EtatEnvoi.echec);

      await app.envois.reprendre();

      expect(depot.lignes, hasLength(1));
    });

    test('une ligne déjà publiée n\'est jamais un orphelin', () async {
      final app = ouvrirApp();
      final brouillon = await brouillonPret(app.brouillons);
      await preparerSurServeur(brouillon, app.brouillons);
      await PublicationEnDeuxTemps(depot).valider(brouillon.id);
      depot.lignes[brouillon.id]!['cree_le'] = maintenant.subtract(
        const Duration(days: 3),
      );

      await app.envois.reprendre(auLancement: true);

      expect(depot.lignes[brouillon.id]!['statut'], statutPublie);
    });
  });

  group('garder en brouillon', () {
    test('défait le serveur, garde le brouillon local', () async {
      final app = ouvrirApp();
      final brouillon = await brouillonPret(app.brouillons);
      depot.echecAuRang = 1;
      await app.envois.envoyer(brouillon.id);

      expect(await app.envois.garderEnBrouillon(brouillon.id), isTrue);

      expect(depot.lignes, isEmpty);
      expect(depot.fichiers, isEmpty);
      expect(await app.file.lister(), isEmpty);
      expect(await app.brouillons.charger(brouillon.id), isNotNull);
    });

    test(
      'hors ligne, la suppression du serveur est gardée pour plus tard',
      () async {
        final app = ouvrirApp();
        final brouillon = await brouillonPret(app.brouillons);
        depot.echecAuRang = 1;
        await app.envois.envoyer(brouillon.id);
        depot.echecAuRang = null;
        // Le brouillon serveur existe (la ligne est écrite après les photos,
        // on la fabrique ici).
        await preparerSurServeur(brouillon, app.brouillons);
        depot.horsLigne = true;

        expect(await app.envois.garderEnBrouillon(brouillon.id), isTrue);
        expect(
          (await app.file.lire(brouillon.id))!.etat,
          EtatEnvoi.aAbandonner,
        );
        expect(depot.lignes, hasLength(1));

        depot.horsLigne = false;
        expect(await app.envois.reprendre(), isEmpty);

        expect(depot.lignes, isEmpty);
        expect(depot.fichiers, isEmpty);
        expect(await app.file.lister(), isEmpty);
        expect(await app.brouillons.charger(brouillon.id), isNotNull);
      },
    );

    test('pendant l\'envoi : arrêté avant le commit', () async {
      final serveur = _DepotLent();
      final app = ouvrirApp(serveur);
      final brouillon = await brouillonPret(app.brouillons);

      final envoi = app.envois.envoyer(brouillon.id);
      await serveur.depotCommence.future;
      final annulation = app.envois.garderEnBrouillon(brouillon.id);
      serveur.feuVert.complete();

      expect((await envoi).statut, StatutEnvoi.annule);
      expect(await annulation, isTrue);
      expect(serveur.appels, isNot(contains('commit')));
      expect(serveur.lignes, isEmpty);
      expect(serveur.fichiers, isEmpty);
      expect(await app.file.lister(), isEmpty);
      expect(await app.brouillons.charger(brouillon.id), isNotNull);
    });

    test('un moment déjà publié reste publié', () async {
      final app = ouvrirApp();
      final brouillon = await brouillonPret(app.brouillons);
      await preparerSurServeur(brouillon, app.brouillons);
      await PublicationEnDeuxTemps(depot).valider(brouillon.id);

      expect(await app.envois.garderEnBrouillon(brouillon.id), isFalse);

      expect(depot.lignes[brouillon.id]!['statut'], statutPublie);
      expect(await app.brouillons.charger(brouillon.id), isNull);
    });
  });

  group('FileEnvoi', () {
    test('relue telle quelle, la plus ancienne d\'abord', () async {
      final file = FileEnvoi(racine);
      await file.ecrire(
        EnvoiPublication(
          brouillonId: 'b',
          auteurId: 'a',
          etat: EtatEnvoi.enAttente,
          creeLe: DateTime(2026, 11, 8, 14),
          commitLance: true,
          tentatives: 3,
          derniereErreur: 'hors ligne',
        ),
      );
      await file.ecrire(
        EnvoiPublication(
          brouillonId: 'a',
          auteurId: 'a',
          etat: EtatEnvoi.echec,
          creeLe: DateTime(2026, 11, 8, 13),
        ),
      );

      final relues = await FileEnvoi(racine).lister();

      expect(relues.map((e) => e.brouillonId), ['a', 'b']);
      final b = relues.last;
      expect(b.etat, EtatEnvoi.enAttente);
      expect(b.commitLance, isTrue);
      expect(b.tentatives, 3);
      expect(b.derniereErreur, 'hors ligne');
      expect(b.creeLe, DateTime(2026, 11, 8, 14));
    });

    test('un fichier illisible est ignoré', () async {
      final file = FileEnvoi(racine);
      await laisserEnvoi(file, 'ok', EtatEnvoi.enAttente);
      File(
        '${racine.path}/envois/casse.json',
      ).writeAsStringSync('{pas du json');

      expect((await file.lister()).map((e) => e.brouillonId), ['ok']);
    });
  });

  group('ReprisePublications', () {
    testWidgets('relance la file à l\'ouverture et à chaque reprise', (
      tester,
    ) async {
      final app = await tester.runAsync(() async {
        final app = ouvrirApp();
        final b = await brouillonPret(app.brouillons);
        await app.envois.mettreEnAttente(b.id);
        return (app: app, id: b.id);
      });
      final reprise = ReprisePublications(app!.app.envois);
      addTearDown(reprise.arreter);

      await tester.runAsync(() async {
        reprise.demarrer();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      expect(depot.lignes[app.id]!['statut'], statutPublie);

      // Un nouveau brouillon en attente part à la reprise de l'app.
      final suivant = await tester.runAsync(() async {
        final b = await brouillonPret(app.app.brouillons);
        await app.app.envois.mettreEnAttente(b.id);
        return b.id;
      });
      expect(depot.lignes.containsKey(suivant), isFalse);
      await tester.runAsync(() async {
        TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      expect(depot.lignes[suivant]!['statut'], statutPublie);
    });
  });
}
