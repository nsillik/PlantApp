import Dependencies
import Foundation
import UserNotifications

struct NotificationScheduler {
    static let maxNotifications = 60

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            reportIssue("Failed to request notification permission: \(error)")
            return false
        }
    }

    func registerTasks(_ tasks: [CareTask]) async {
        let center = UNUserNotificationCenter.current()
        let sorted = tasks.sorted { $0.dueDate < $1.dueDate }
        let soonest = Array(sorted.prefix(Self.maxNotifications))

        var requests: [UNNotificationRequest] = []
        for task in soonest {
            let content = UNMutableNotificationContent()
            let titleFormat = String(localized: "Time to care for %@")
            content.title = String(format: titleFormat, task.plantName)
            content.body = notificationBody(for: task)
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: task.dueDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(task.plantID)-\(task.eventType.rawValue)-\(Int(task.dueDate.timeIntervalSince1970))",
                content: content,
                trigger: trigger
            )
            requests.append(request)
        }

        let identifiers = Set(requests.map(\.identifier))

        let existing = await center.pendingNotificationRequests()
        for existingRequest in existing {
            if !identifiers.contains(existingRequest.identifier) {
                center.removePendingNotificationRequests(withIdentifiers: [existingRequest.identifier])
            }
        }

        for request in requests {
            do {
                try await center.add(request)
            } catch {
                reportIssue("Failed to add notification: \(error)")
            }
        }
    }

    func removeAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func notificationBody(for task: CareTask) -> String {
        let format: String
        switch task.eventType {
        case .watered:
            format = String(localized: "%@ needs watering today.")
        case .fertilized:
            format = String(localized: "%@ is due for fertilizing.")
        case .pruned:
            format = String(localized: "%@ is ready for pruning.")
        case .repotted:
            format = String(localized: "%@ needs repotting.")
        }
        return String(format: format, task.plantName)
    }
}
