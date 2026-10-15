import SwiftData
import SwiftUI
import UserNotifications

@main
struct FeinsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel(launch: .current)
    @AppStorage(SettingsKeys.appearance) private var appearance: Appearance = .system

    init() {
        Self.configureNavigationBarFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(model.launch.forcedAppearance?.colorScheme ?? appearance.colorScheme)
                .tint(Theme.accent)
        }
        .modelContainer(model.container)
    }
}

/// Öffnet beim Tippen auf eine Erinnerung direkt den Random Chooser.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static let openChooser = Notification.Name("feins.openChooser")

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run {
            NotificationCenter.default.post(name: Self.openChooser, object: nil)
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

extension FeinsApp {
    /// Serifen-Schrift für die grossen Navigationstitel.
    static func configureNavigationBarFonts() {
        let base = UIFont.preferredFont(forTextStyle: .largeTitle).fontDescriptor
        if let serif = base.withDesign(.serif)?.withSymbolicTraits(.traitBold) {
            UINavigationBar.appearance().largeTitleTextAttributes = [.font: UIFont(descriptor: serif, size: 0)]
        }
        let inline = UIFont.preferredFont(forTextStyle: .headline).fontDescriptor
        if let serif = inline.withDesign(.serif)?.withSymbolicTraits(.traitBold) {
            UINavigationBar.appearance().titleTextAttributes = [.font: UIFont(descriptor: serif, size: 0)]
        }
    }
}
