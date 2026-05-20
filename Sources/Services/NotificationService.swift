import Foundation
import UserNotifications

/// Manages macOS notifications for agent status changes
final class NotificationService {
    static let shared = NotificationService()

    private var isAvailable = false

    private init() {
        // Only use UNUserNotificationCenter when running in a proper app bundle
        if Bundle.main.bundleIdentifier != nil {
            isAvailable = true
            requestPermission()
        } else {
            print("[Mast] Notifications unavailable (not running in app bundle)")
        }
    }

    func requestPermission() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("[Mast] Notification permission error: \(error)")
            }
        }
    }

    /// Send a notification when an agent needs attention
    func notifyNeedsInput(agent: Agent) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = L10n.notifNeedsInput
        content.body = agent.displayName
        content.sound = .default
        content.categoryIdentifier = "AGENT_STATUS"

        let request = UNNotificationRequest(
            identifier: "needs-input-\(agent.id.uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Send a notification when an agent encounters an error
    func notifyError(agent: Agent) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = L10n.notifError
        content.body = agent.displayName
        content.sound = .defaultCritical
        content.categoryIdentifier = "AGENT_STATUS"

        let request = UNNotificationRequest(
            identifier: "error-\(agent.id.uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
