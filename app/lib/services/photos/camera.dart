import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Le flash du téléphone.
enum ModeFlash { auto, active, desactive }

/// Où en est la caméra : l'écran choisit quoi montrer d'après cet état.
enum EtatCamera {
  /// Pas démarrée, ou libérée (arrière-plan, écran quitté).
  eteinte,

  /// En train de s'ouvrir (autorisation demandée, viseur en préparation).
  demarrage,

  /// Le viseur tourne : on peut prendre une photo.
  prete,

  /// L'utilisateur a refusé l'accès à la caméra.
  refusee,

  /// Pas de caméra utilisable (appareil sans caméra, erreur matérielle).
  indisponible,
}

/// Une photo prise avec la caméra de l'app, avec l'heure de la prise
/// (c'est elle qui date le repas, pas un EXIF qu'on ne relit pas).
typedef PhotoPrise = ({Uint8List octets, DateTime priseLe});

/// La caméra en direct de l'écran de création. Injectable : l'écran reçoit
/// un [CameraService], la vraie caméra en production (`CameraServiceAppareil`)
/// et [FausseCamera] dans les tests.
///
/// Ne dépend pas du micro : aucune vidéo, aucun son.
abstract interface class CameraService {
  /// L'état courant ; l'écran s'y abonne pour redessiner.
  ValueListenable<EtatCamera> get etat;

  /// Le flash choisi (gardé d'une ouverture à l'autre).
  ModeFlash get flash;

  /// Ouvre la caméra et la garde ouverte tant que l'écran ne l'a pas
  /// fermée : libérée quand l'app perd le focus
  /// (`AppLifecycleState.inactive`), relancée à la reprise. Sans effet si
  /// déjà démarrée.
  Future<void> demarrer();

  /// Libère la caméra pour de bon (écran quitté) : plus de relance.
  Future<void> fermer();

  Future<void> definirFlash(ModeFlash mode);

  /// Prend une photo ; `null` si la caméra n'est pas prête, déjà occupée
  /// ou en échec.
  Future<PhotoPrise?> prendrePhoto();

  /// Le viseur en direct ; vide tant que la caméra n'est pas prête.
  Widget apercu();
}

/// Le cycle de vie commun à toute caméra : ouvertures et fermetures
/// jouées l'une après l'autre (jamais deux à la fois), libération dès que
/// l'app devient inactive, relance à la reprise. Les classes filles ne
/// décrivent que le matériel.
abstract class CameraDeBase
    with WidgetsBindingObserver
    implements CameraService {
  final _etat = ValueNotifier(EtatCamera.eteinte);
  ModeFlash _flash = ModeFlash.auto;
  var _voulue = false;
  var _aRelancer = false;
  Future<void> _file = Future.value();

  @override
  ValueListenable<EtatCamera> get etat => _etat;

  @override
  ModeFlash get flash => _flash;

  /// Ouvre le matériel. Renvoie l'état atteint : [EtatCamera.prete],
  /// [EtatCamera.refusee] ou [EtatCamera.indisponible].
  @protected
  Future<EtatCamera> ouvrirMateriel(ModeFlash flash);

  @protected
  Future<void> fermerMateriel();

  @protected
  Future<void> appliquerFlash(ModeFlash mode);

  @protected
  Future<PhotoPrise?> declencherMateriel();

  @override
  Future<void> demarrer() {
    if (_voulue) return _file;
    _voulue = true;
    WidgetsBinding.instance.addObserver(this);
    return _enchainer(_ouvrir);
  }

  @override
  Future<void> fermer() {
    _voulue = false;
    _aRelancer = false;
    WidgetsBinding.instance.removeObserver(this);
    return _enchainer(_eteindre);
  }

  @override
  Future<void> definirFlash(ModeFlash mode) {
    _flash = mode;
    return _enchainer(() async {
      if (_etat.value == EtatCamera.prete) await appliquerFlash(mode);
    });
  }

  @override
  Future<PhotoPrise?> prendrePhoto() async {
    if (_etat.value != EtatCamera.prete) return null;
    try {
      return await declencherMateriel();
    } catch (_) {
      return null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      surCycleDeVie(state);

  /// Libère à `inactive` (la caméra ne doit pas rester prise quand l'app
  /// n'a plus le focus) et relance à `resumed`.
  void surCycleDeVie(AppLifecycleState etatApp) {
    if (!_voulue) return;
    switch (etatApp) {
      case AppLifecycleState.inactive:
        // Même si l'ouverture n'a pas encore commencé (file d'attente).
        _aRelancer =
            _aRelancer ||
            (_etat.value != EtatCamera.refusee &&
                _etat.value != EtatCamera.indisponible);
        unawaited(_enchainer(_eteindre));
      case AppLifecycleState.resumed:
        if (!_aRelancer) return;
        _aRelancer = false;
        unawaited(
          _enchainer(() async {
            if (_voulue && _etat.value == EtatCamera.eteinte) await _ouvrir();
          }),
        );
      case AppLifecycleState.hidden ||
          AppLifecycleState.paused ||
          AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _enchainer(Future<void> Function() action) {
    final suite = _file.then((_) => action());
    _file = suite.catchError((Object _) {});
    return suite;
  }

  Future<void> _ouvrir() async {
    if (!_voulue || _etat.value == EtatCamera.prete) return;
    _etat.value = EtatCamera.demarrage;
    try {
      final atteint = await ouvrirMateriel(_flash);
      if (_voulue) {
        _etat.value = atteint;
      } else {
        await fermerMateriel();
        _etat.value = EtatCamera.eteinte;
      }
    } catch (_) {
      _etat.value = EtatCamera.indisponible;
    }
  }

  Future<void> _eteindre() async {
    // Un refus ou une panne restent affichés : ce n'est pas la reprise
    // de l'app qui les règle.
    if (_etat.value != EtatCamera.prete &&
        _etat.value != EtatCamera.demarrage) {
      return;
    }
    try {
      await fermerMateriel();
    } finally {
      _etat.value = EtatCamera.eteinte;
    }
  }
}

/// Une caméra pour les tests : pas de matériel, des compteurs pour
/// vérifier ce que l'écran a demandé.
class FausseCamera extends CameraDeBase {
  FausseCamera({
    this.etatAtteint = EtatCamera.prete,
    Uint8List? octetsPhoto,
    this.delaiOuverture = Duration.zero,
    DateTime Function()? maintenant,
  }) : octetsPhoto =
           octetsPhoto ?? Uint8List.fromList(const [0xFF, 0xD8, 0xFF]),
       _maintenant = maintenant ?? DateTime.now;

  /// Ce que l'ouverture donne : [EtatCamera.refusee] pour simuler un refus.
  EtatCamera etatAtteint;
  Uint8List octetsPhoto;
  Duration delaiOuverture;
  final DateTime Function() _maintenant;

  var ouvertures = 0;
  var fermetures = 0;
  final photosPrises = <PhotoPrise>[];
  final flashsAppliques = <ModeFlash>[];

  /// La caméra est-elle ouverte en ce moment (côté matériel simulé) ?
  var ouverte = false;

  @override
  Future<EtatCamera> ouvrirMateriel(ModeFlash flash) async {
    ouvertures++;
    if (delaiOuverture > Duration.zero) {
      await Future<void>.delayed(delaiOuverture);
    }
    if (etatAtteint == EtatCamera.prete) {
      ouverte = true;
      flashsAppliques.add(flash);
    }
    return etatAtteint;
  }

  @override
  Future<void> fermerMateriel() async {
    fermetures++;
    ouverte = false;
  }

  @override
  Future<void> appliquerFlash(ModeFlash mode) async =>
      flashsAppliques.add(mode);

  @override
  Future<PhotoPrise?> declencherMateriel() async {
    final photo = (octets: octetsPhoto, priseLe: _maintenant());
    photosPrises.add(photo);
    return photo;
  }

  @override
  Widget apercu() => const SizedBox.expand(key: Key('apercu_fausse_camera'));
}
