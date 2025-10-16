import SwiftUI
import SwiftData
import UserNotifications

@main
struct TaskTrackerApp: App {
    private let modelContainer: ModelContainer

    var body: some Scene {
        WindowGroup {
            TaskListView()
        }
        .modelContainer(modelContainer)
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
        let configuration = ModelConfiguration(for: TaskSchemaV2.self, migrationPlan: TaskMigrationPlan.self)
        modelContainer = try! ModelContainer(for: TaskSchemaV2.self, configurations: configuration)

        // Ask once on first launch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}