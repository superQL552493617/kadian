import SwiftUI
import UserNotifications

/// 启动时就接管通知：点通知冷启动 App 时也能收到
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// App 开着时也显示通知横幅
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    /// 点通知：通知里带的 route 交给网页（比如打开某一项）
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let route = response.notification.request.content.userInfo["route"] as? String ?? ""
        await MainActor.run { WebBridge.pendingNotificationRoute = route.isEmpty ? "home" : route }
        await MainActor.run { NotificationCenter.default.post(name: .openRoute, object: nil) }
    }
}

@main
struct StarterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var purchases = Purchases()

    var body: some Scene {
        WindowGroup {
            WebRootView()
                .environmentObject(purchases)
                .task { await purchases.start() }
        }
    }
}

extension Notification.Name {
    static let openRoute = Notification.Name("openRoute")
}
