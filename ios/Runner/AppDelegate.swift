import Firebase
import FirebaseCore
import FirebaseMessaging
import Flutter
import NetworkExtension
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()

    // Set up notification delegate
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self

      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { granted, error in
          if granted {
            print("✅ iOS Notification permission granted")
          } else {
            print("❌ iOS Notification permission denied")
          }
        }
      )
    }

    // Register for remote notifications
    application.registerForRemoteNotifications()

    // VPN Detection Channel using NEVPNManager (accurate, no false positives)
    let controller = window?.rootViewController as! FlutterViewController
    let vpnChannel = FlutterMethodChannel(
      name: "com.elrace/vpn_check",
      binaryMessenger: controller.binaryMessenger
    )
    vpnChannel.setMethodCallHandler { call, result in
      if call.method == "isVpnActive" {
        // Check IKEv2 / IPSec VPN profiles first (synchronous)
        let sysVpnStatus = NEVPNManager.shared().connection.status
        let sysVpnActive = sysVpnStatus == .connected || sysVpnStatus == .connecting
        print("🔒 iOS NEVPNManager status: \(sysVpnStatus) - Active: \(sysVpnActive)")
        
        if sysVpnActive {
          print("✅ iOS: System VPN detected via NEVPNManager")
          result(true)
          return
        }
        
        // Check Tunnel Provider VPN apps (most VPN apps use this) - Asynchronous
        print("🔒 iOS: Checking TunnelProvider VPN apps...")
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
          if let error = error {
            print("⚠️ iOS: Error loading VPN preferences: \(error.localizedDescription)")
            result(false)
            return
          }
          
          guard let managers = managers else {
            print("⚠️ iOS: No VPN managers returned (managers is nil)")
            result(false)
            return
          }
          
          print("🔒 iOS: Loaded \(managers.count) VPN managers")
          let vpnActive = managers.contains { manager in
            let status = manager.connection.status
            let isActive = status == .connected || status == .connecting
            print("   - VPN Manager status: \(status) - Active: \(isActive)")
            return isActive
          }
          
          print(vpnActive ? "✅ iOS: TunnelProvider VPN detected" : "❌ iOS: No TunnelProvider VPN detected")
          result(vpnActive)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle successful registration for remote notifications
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    print("✅ Successfully registered for remote notifications")
    print("📱 Device Token: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")

    Messaging.messaging().token { token, error in
      if let error = error {
        print("❌ Failed to fetch FCM token after APNS registration: \(error.localizedDescription)")
      } else if let token = token {
        print("✅ iOS FCM token (native callback): \(token)")
      } else {
        print("⚠️ iOS FCM token is nil after APNS registration")
      }
    }
  }

  // Handle failure to register for remote notifications
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
  }

  // Handle notification when app is in foreground (iOS 10+)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    print("📬 Notification received in foreground: \(userInfo)")

    // Show notification even when app is in foreground
    if #available(iOS 14.0, *) {
      completionHandler([[.banner, .sound, .badge]])
    } else {
      completionHandler([[.alert, .sound, .badge]])
    }
  }

  // Handle notification tap
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    print("📲 Notification tapped: \(userInfo)")

    completionHandler()
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    print("📩 iOS remote notification received (bg/silent): \(userInfo)")
    completionHandler(.newData)
  }
}
