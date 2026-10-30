import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Set before launch finishes, so a tap that cold-launched the app is
    // delivered here and buffered until Dart asks for it.
    UNUserNotificationCenter.current().delegate = PushNotificationsPlugin.shared
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PushNotificationsPlugin") {
      PushNotificationsPlugin.register(with: registrar)
    }
  }
}

/// APNs for the Dart side (lib/core/push/push_channel.dart): permission,
/// the device token, which APNs environment it belongs to, and taps.
/// Written here rather than taken from a plugin package so the app
/// carries no Firebase or third-party push SDK.
final class PushNotificationsPlugin: NSObject, FlutterPlugin, UNUserNotificationCenterDelegate {
  static let shared = PushNotificationsPlugin()

  private var channel: FlutterMethodChannel?
  private var pendingToken: [FlutterResult] = []
  private var initialNotification: [AnyHashable: Any]?
  // False until Dart has asked for the initial notification, which is
  // also when its tap handler is listening. A tap before then is kept,
  // not sent into a channel nobody is reading yet.
  private var dartIsListening = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "app.mantelier/push", binaryMessenger: registrar.messenger())
    shared.channel = channel
    registrar.addMethodCallDelegate(shared, channel: channel)
    registrar.addApplicationDelegate(shared)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getAuthorizationStatus":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        DispatchQueue.main.async { result(Self.describe(settings.authorizationStatus)) }
      }
    case "requestAuthorization":
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
        granted, _ in
        DispatchQueue.main.async { result(granted) }
      }
    case "registerForRemoteNotifications":
      pendingToken.append(result)
      UIApplication.shared.registerForRemoteNotifications()
    case "getApnsEnvironment":
      result(Self.apnsEnvironment())
    case "takeInitialNotification":
      result(initialNotification.map(Self.stringKeyed))
      initialNotification = nil
      dartIsListening = true
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Token

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
    pendingToken.forEach { $0(hex) }
    pendingToken.removeAll()
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    pendingToken.forEach {
      $0(FlutterError(code: "register_failed", message: error.localizedDescription, details: nil))
    }
    pendingToken.removeAll()
  }

  // MARK: Presentation and taps

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    channel?.invokeMethod(
      "onForegroundNotification",
      arguments: Self.stringKeyed(notification.request.content.userInfo))
    completionHandler([.banner, .list])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    if dartIsListening, let channel = channel {
      channel.invokeMethod("onNotificationTap", arguments: Self.stringKeyed(userInfo))
    } else {
      initialNotification = userInfo
    }
    completionHandler()
  }

  // MARK: Helpers

  private static func describe(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .authorized: return "authorized"
    case .provisional: return "provisional"
    case .ephemeral: return "authorized"
    case .denied: return "denied"
    case .notDetermined: return "notDetermined"
    @unknown default: return "notDetermined"
    }
  }

  /// Which APNs host this build's tokens belong to. An App Store or
  /// TestFlight build carries no embedded provisioning profile and always
  /// uses production; a development-signed build says so in its profile.
  /// send-push corrects a wrong guess on BadDeviceToken either way.
  private static func apnsEnvironment() -> String {
    guard
      let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
      let data = try? Data(contentsOf: url),
      let text = String(data: data, encoding: .isoLatin1),
      let keyRange = text.range(of: "<key>aps-environment</key>")
    else { return "production" }
    let rest = text[keyRange.upperBound...]
    guard
      let open = rest.range(of: "<string>"),
      let close = rest.range(of: "</string>", range: open.upperBound..<rest.endIndex)
    else { return "sandbox" }
    return rest[open.upperBound..<close.lowerBound] == "production" ? "production" : "sandbox"
  }

  private static func stringKeyed(_ info: [AnyHashable: Any]) -> [String: Any] {
    var out: [String: Any] = [:]
    for (key, value) in info {
      guard let key = key as? String, key != "aps" else { continue }
      out[key] = value
    }
    return out
  }
}
