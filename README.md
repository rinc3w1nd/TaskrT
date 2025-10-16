TaskTracker/
├─ TaskTrackerApp.swift          // App entry, asks for notification permission
├─ Models.swift                  // SwiftData models (Task, Tag)
├─ ColorLogic.swift              // Thresholds + color mapping
├─ NotificationManager.swift     // Schedules/cancels UNUserNotifications
├─ TaskListView.swift            // Main list with sort/filter/color pills
├─ TaskEditorView.swift          // Create/Edit a task with freeform tags
├─ SettingsView.swift            // Threshold configuration (blue/yellow/orange/red)
└─ TagSuggestions.swift          // Suggestion helper from existing tasks