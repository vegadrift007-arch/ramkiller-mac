import Foundation
import UserNotifications

@MainActor
public final class NotificationService {
    public static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    public func requestAuthorization() async {
        do {
            try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            NSLog("[notif] auth failed: \(error)")
        }
    }

    public func deliver(level: AlertLevel, message: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = "BeagleX — \(level.label)"
        content.body = message
        content.sound = level == .emergency ? .defaultCritical : .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    public func clear(identifier: String) {
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
