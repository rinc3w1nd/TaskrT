import Foundation
import SwiftData

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case pending, done, canceled
    var id: String { rawValue }
}

enum TaskSchemaV1: VersionedSchema {
    static let version = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Task.self, Tag.self] }

    @Model
    final class Task: Identifiable {
        var title: String
        var notes: String
        var createdAt: Date
        var dueDate: Date?
        var statusRaw: String
        @Relationship(deleteRule: .nullify) var tags: [Tag] = []

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

    @Model
    final class Tag: Identifiable, Hashable {
        @Attribute(.unique) var name: String

        init(name: String) {
            self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

enum TaskSchemaV2: VersionedSchema {
    static let version = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Task.self, Tag.self, TaskWorkNote.self, TaskAttachment.self] }

    @Model
    final class TaskWorkNote: Identifiable {
        var text: String
        var createdAt: Date
        var position: Int

        @Relationship(inverse: \Task.notes) var task: Task?

        init(text: String, createdAt: Date = Date(), position: Int, task: Task? = nil) {
            self.text = text
            self.createdAt = createdAt
            self.position = position
            self.task = task
        }
    }

    @Model
    final class TaskAttachment: Identifiable {
        var fileName: String
        var contentType: String?
        var fileSize: Int?
        var bookmarkData: Data?
        var storedRelativePath: String?
        var createdAt: Date
        var position: Int

        @Relationship(inverse: \Task.attachments) var task: Task?

        init(fileName: String,
             contentType: String? = nil,
             fileSize: Int? = nil,
             bookmarkData: Data? = nil,
             storedRelativePath: String? = nil,
             createdAt: Date = Date(),
             position: Int,
             task: Task? = nil) {
            self.fileName = fileName
            self.contentType = contentType
            self.fileSize = fileSize
            self.bookmarkData = bookmarkData
            self.storedRelativePath = storedRelativePath
            self.createdAt = createdAt
            self.position = position
            self.task = task
        }

        var isBookmark: Bool { bookmarkData != nil && storedRelativePath == nil }
    }

    @Model
    final class Task: Identifiable {
        var title: String
        var createdAt: Date
        var dueDate: Date?
        var statusRaw: String

        @Relationship(deleteRule: .nullify) var tags: [Tag] = []
        @Relationship(deleteRule: .cascade, inverse: \TaskWorkNote.task)
        var notes: [TaskWorkNote] = []
        @Relationship(deleteRule: .cascade, inverse: \TaskAttachment.task)
        var attachments: [TaskAttachment] = []

        var status: TaskStatus {
            get { TaskStatus(rawValue: statusRaw) ?? .pending }
            set { statusRaw = newValue.rawValue }
        }

        init(title: String,
             initialNote: String = "",
             dueDate: Date? = nil,
             status: TaskStatus = .pending) {
            self.title = title
            self.createdAt = Date()
            self.dueDate = dueDate
            self.statusRaw = status.rawValue
            if !initialNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                _ = addNote(text: initialNote)
            }
        }

        var latestNote: TaskWorkNote? {
            notes.sorted { $0.position < $1.position }.last
        }

        @discardableResult
        func addNote(text: String, createdAt: Date = Date()) -> TaskWorkNote {
            let nextPosition = (notes.map { $0.position }.max() ?? -1) + 1
            let note = TaskWorkNote(text: text, createdAt: createdAt, position: nextPosition, task: self)
            notes.append(note)
            return note
        }

        @discardableResult
        func updateLatestNote(text: String, createdAt: Date = Date()) -> TaskWorkNote {
            if let latest = latestNote {
                latest.text = text
                latest.createdAt = createdAt
                return latest
            }
            return addNote(text: text, createdAt: createdAt)
        }

        func latestNoteText() -> String {
            latestNote?.text ?? ""
        }

        @discardableResult
        func addAttachment(fileName: String,
                           contentType: String? = nil,
                           fileSize: Int? = nil,
                           bookmarkData: Data? = nil,
                           storedRelativePath: String? = nil,
                           createdAt: Date = Date()) -> TaskAttachment {
            let nextPosition = (attachments.map { $0.position }.max() ?? -1) + 1
            let attachment = TaskAttachment(fileName: fileName,
                                            contentType: contentType,
                                            fileSize: fileSize,
                                            bookmarkData: bookmarkData,
                                            storedRelativePath: storedRelativePath,
                                            createdAt: createdAt,
                                            position: nextPosition,
                                            task: self)
            attachments.append(attachment)
            return attachment
        }

        func replaceNotes(with text: String, createdAt: Date = Date()) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                notes.removeAll()
            } else {
                _ = updateLatestNote(text: trimmed, createdAt: createdAt)
            }
        }
    }

    @Model
    final class Tag: Identifiable, Hashable {
        @Attribute(.unique) var name: String

        init(name: String) {
            self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

enum TaskMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [TaskSchemaV1.self, TaskSchemaV2.self] }

    static var stages: [MigrationStage] {
        [MigrationStage.custom(fromVersion: TaskSchemaV1.version,
                               toVersion: TaskSchemaV2.version,
                               willMigrate: migrateLegacyNotes,
                               didMigrate: nil)]
    }

    private static func migrateLegacyNotes(context: MigrationStage.CustomMigrationContext,
                                           modelContext: ModelContext) throws {
        var tagMap: [String: TaskSchemaV2.Tag] = [:]

        try context.enumerate(TaskSchemaV1.Tag.self) { oldTag in
            let name = oldTag.model.name
            if tagMap[name] == nil {
                let newTag = TaskSchemaV2.Tag(name: name)
                modelContext.insert(newTag)
                tagMap[name] = newTag
            }
        }

        try context.enumerate(TaskSchemaV1.Task.self) { oldTask in
            let source = oldTask.model
            let newTask = TaskSchemaV2.Task(title: source.title,
                                            initialNote: "",
                                            dueDate: source.dueDate,
                                            status: TaskStatus(rawValue: source.statusRaw) ?? .pending)
            newTask.createdAt = source.createdAt
            newTask.statusRaw = source.statusRaw
            newTask.tags = source.tags.compactMap { tagMap[$0.name] }
            if !source.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                _ = newTask.addNote(text: source.notes, createdAt: source.createdAt)
            }
            modelContext.insert(newTask)
        }
    }
}

typealias Task = TaskSchemaV2.Task
typealias Tag = TaskSchemaV2.Tag
typealias TaskWorkNote = TaskSchemaV2.TaskWorkNote
typealias TaskAttachment = TaskSchemaV2.TaskAttachment
