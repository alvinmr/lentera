import AppKit
import UserNotifications

nonisolated enum BatchNotification {
  @MainActor static func post(title: String, body: String) {
    guard UserDefaults.standard.object(forKey: "notifyOnCompletion") as? Bool ?? true else {
      return
    }
    guard !NSApplication.shared.isActive else { return }
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert]) { _, _ in }
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
  }
}
