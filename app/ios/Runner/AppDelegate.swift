import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Les notifications affichées ou touchées passent par ici, puis par
    // les plugins (dont NotificationsTabl ci-dessous).
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NotificationsTabl") {
      NotificationsTabl.register(with: registrar)
    }
  }
}

/// Les notifications du téléphone, pour Dart (`NotificationsSystemeSupabase`,
/// canal `tabl/notifications`) : l'autorisation, le jeton de l'appareil
/// pour APNs, et la notification touchée.
final class NotificationsTabl: NSObject, FlutterPlugin {
  private let canal: FlutterMethodChannel
  /// Dart écoute-t-il déjà ? Sinon, la notification qui a ouvert l'app
  /// attend qu'il soit prêt.
  private var dartPret = false
  private var toucheeEnAttente: [String: Any]?

  init(canal: FlutterMethodChannel) {
    self.canal = canal
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let canal = FlutterMethodChannel(
      name: "tabl/notifications", binaryMessenger: registrar.messenger())
    let instance = NotificationsTabl(canal: canal)
    registrar.addMethodCallDelegate(instance, channel: canal)
    registrar.addApplicationDelegate(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "activer":
      // iOS ne pose la question qu'une fois ; ensuite il répond seul.
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
        accordee, _ in
        DispatchQueue.main.async {
          if accordee { UIApplication.shared.registerForRemoteNotifications() }
          result(accordee)
        }
      }
    case "pret":
      dartPret = true
      if let enAttente = toucheeEnAttente {
        toucheeEnAttente = nil
        canal.invokeMethod("touchee", arguments: enAttente)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let jeton = deviceToken.map { String(format: "%02x", $0) }.joined()
    canal.invokeMethod("jeton", arguments: jeton)
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    canal.invokeMethod("erreur", arguments: error.localizedDescription)
  }

  // App ouverte : la notification s'affiche quand même, en bannière.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    var donnees: [String: Any] = [:]
    for (cle, valeur) in response.notification.request.content.userInfo {
      if let cle = cle as? String, cle != "aps", let texte = valeur as? String {
        donnees[cle] = texte
      }
    }
    if dartPret {
      canal.invokeMethod("touchee", arguments: donnees)
    } else {
      toucheeEnAttente = donnees
    }
    completionHandler()
  }
}
