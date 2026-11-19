import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OperoPushPlugin") {
      OperoPushPlugin.register(with: registrar)
    }
  }
}

/// Apple push registration without Firebase: hands the APNs device token to Dart,
/// shows pushes while the app is open and reports taps.
final class OperoPushPlugin: NSObject, FlutterPlugin {
  private let channel: FlutterMethodChannel
  private var pendingTokenResult: FlutterResult?

  init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "opero/push", binaryMessenger: registrar.messenger())
    let instance = OperoPushPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addApplicationDelegate(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestToken":
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
        DispatchQueue.main.async {
          guard granted else {
            result(nil)
            return
          }
          self.pendingTokenResult?(nil)
          self.pendingTokenResult = result
          UIApplication.shared.registerForRemoteNotifications()
        }
      }
    case "permissionStatus":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        let status: String
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: status = "granted"
        case .denied: status = "denied"
        default: status = "notDetermined"
        }
        DispatchQueue.main.async { result(status) }
      }
    case "setBadge":
      let count = (call.arguments as? Int) ?? 0
      if #available(iOS 16.0, *) {
        UNUserNotificationCenter.current().setBadgeCount(count)
      } else {
        UIApplication.shared.applicationIconBadgeNumber = count
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    pendingTokenResult?(token)
    pendingTokenResult = nil
  }

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    pendingTokenResult?(FlutterError(code: "register_failed", message: error.localizedDescription, details: nil))
    pendingTokenResult = nil
  }

  private func isRemote(_ notification: UNNotification) -> Bool {
    return notification.request.trigger is UNPushNotificationTrigger
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    guard isRemote(notification) else { return }
    channel.invokeMethod("onPush", arguments: notification.request.content.userInfo as? [String: Any])
    completionHandler([.banner, .list, .sound, .badge])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    guard isRemote(response.notification) else { return }
    channel.invokeMethod("onTap", arguments: response.notification.request.content.userInfo as? [String: Any])
    completionHandler()
  }
}
