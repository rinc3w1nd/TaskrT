import SwiftUI
import SwiftData
import UserNotifications

@main
struct TaskTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            TaskListView()
        }
        .modelContainer(for: [Task.self, Tag.self])
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Task") {
                    NotificationCenter.default.post(name: .init("NEW_TASK_SHORTCUT"), object: nil)
                }.keyboardShortcut("n", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
        }
    }

    init() {
        // Ask once on first launch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}