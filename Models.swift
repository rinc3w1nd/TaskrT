import Foundation
import SwiftData

@Model
final class Tag: Identifiable, Hashable {
    @Attribute(.unique) var name: String

    init(name: String) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case pending, done, canceled
    var id: String { rawValue }
}

@Model
final class Task: Identifiable {
    var title: String
    var notes: String
    var createdAt: Date
    var dueDate: Date?
    var statusRaw: String
    @Relationship(deleteRule: .nullify, inverse: \TagTasks.tag) var tags: [Tag] = []

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(title: String,
         notes: String = "",
         dueDate: Date? = nil,
         status: TaskStatus = .pending) {
        self.title = title
        self.notes = notes
        self.createdAt = Date()
        self.dueDate = dueDate
        self.statusRaw = status.rawValue
    }
}

// A lightweight join helper so each Tag knows which Tasks reference it (inverse)
@Model
final class TagTasks {
    @Relationship var tag: Tag
    @Relationship var task: Task
    init(tag: Tag, task: Task) {
        self.tag = tag
        self.task = task
    }
}