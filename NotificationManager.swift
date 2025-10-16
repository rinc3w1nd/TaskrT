import Foundation
import UserNotifications
import SwiftData

enum NotifyWhen: String, CaseIterable, Identifiable {
    case atDue, oneHour, oneDay
    var id: String { rawValue }

    func triggerDate(for due: Date) -> Date {
        switch self {
        case .atDue: return due
        case .oneHour: return Calendar.current.date(byAdding: .hour, value: -1, to: due) ?? due
        case .oneDay: return Calendar.current.date(byAdding: .day, value: -1, to: due) ?? due
        }
    }
}

struct NotificationManager {
    static func scheduleNotifications(for task: Task, when: [NotifyWhen] = [.oneDay, .oneHour, .atDue]) {
        // Clear old ones first
        cancelNotifications(for: task)

        guard task.status == .pending, let due = task.dueDate else { return }
        let center = UNUserNotificationCenter.current()

        for moment in when {
            let fire = moment.triggerDate(for: due)
            guard fire > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Task Due \(moment == .atDue ? "Now" : "Soon")"
            content.body = task.title
            content.sound = .default

            var dateComponents = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: fire)
            dateComponents.second = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let req = UNNotificationRequest(identifier: notificationID(for: task, moment: moment), content: content, trigger: trigger)
            center.add(req)
        }
    }

    static func cancelNotifications(for task: Task) {
        let ids = NotifyWhen.allCases.map { notificationID(for: task, moment: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static func notificationID(for task: Task, moment: NotifyWhen) -> String {
        "\(task.id)-\(moment.rawValue)"
    }
}