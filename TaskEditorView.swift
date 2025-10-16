import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    @State private var title: String
    @State private var dueDateEnabled: Bool
    @State private var dueDate: Date
    @State private var tagInput: String
    @State private var status: TaskStatus

    @State private var noteDrafts: [NoteDraft]
    @State private var newNoteText: String = ""
    @State private var useCurrentTimestamp: Bool = true
    @State private var manualTimestamp: Date = Date()

    @State private var attachmentDrafts: [AttachmentDraft]
    @State private var pendingCopyPaths: Set<String> = []
    @State private var showBookmarkImporter = false
    @State private var showCopyImporter = false
    @State private var alertMessage: IdentifiableMessage?

    let isNew: Bool
    let onSave: (Task) -> Void

    private var task: Task

    init(task: Task, isNew: Bool, onSave: @escaping (Task) -> Void) {
        self.task = task
        _title = State(initialValue: task.title)
        _dueDateEnabled = State(initialValue: task.dueDate != nil)
        _dueDate = State(initialValue: task.dueDate ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
        _tagInput = State(initialValue: task.tags.map { $0.name }.joined(separator: ", "))
        _status = State(initialValue: task.status)

        let existingNotes = task.notes.sorted { $0.position < $1.position }
        _noteDrafts = State(initialValue: existingNotes.enumerated().map { index, note in
            NoteDraft(id: UUID(), text: note.text, createdAt: note.createdAt, position: index)
        })

        let existingAttachments = task.attachments.sorted { $0.position < $1.position }
        _attachmentDrafts = State(initialValue: existingAttachments.enumerated().map { index, attachment in
            AttachmentDraft(id: UUID(),
                            fileName: attachment.fileName,
                            contentType: attachment.contentType,
                            fileSize: attachment.fileSize,
                            bookmarkData: attachment.bookmarkData,
                            storedRelativePath: attachment.storedRelativePath,
                            createdAt: attachment.createdAt,
                            position: index)
        })

        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(isNew ? "New Task" : "Edit Task")
                    .font(.title2).bold()

                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)

                notesSection
                newNoteComposer

                attachmentsSection

                Toggle("Has due date", isOn: $dueDateEnabled.animation())
                if dueDateEnabled {
                    DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                }

                tagsSection

                Picker("Status", selection: $status) {
                    ForEach(TaskStatus.allCases) { s in
                        Text(s.rawValue.capitalized).tag(s)
                    }
                }
                .pickerStyle(.segmented)

                actionButtons
            }
            .padding(20)
        }
        .frame(width: 600)
        .alert(item: $alertMessage) { message in
            Alert(title: Text("Attachment Error"), message: Text(message.message), dismissButton: .default(Text("OK")))
        }
        .fileImporter(isPresented: $showBookmarkImporter,
                      allowedContentTypes: [.item],
                      allowsMultipleSelection: false) { result in
            handleBookmarkImport(result: result)
        }
        .fileImporter(isPresented: $showCopyImporter,
                      allowedContentTypes: [.item],
                      allowsMultipleSelection: false) { result in
            handleCopyImport(result: result)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Work Notes")
                    .font(.headline)
                Spacer()
                if !noteDrafts.isEmpty {
                    Button("Clear All", role: .destructive) {
                        noteDrafts.removeAll()
                    }
                    .buttonStyle(.borderless)
                }
            }

            if noteDrafts.isEmpty {
                Text("No notes yet. Add one below to capture progress.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(sortedNotes) { draft in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(formattedDate(draft.createdAt))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(role: .destructive) {
                                    removeNote(draft)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                            Text(draft.text)
                                .font(.body)
                        }
                        .padding(12)
                        .background(cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2))
                        )
                    }
                }
            }
        }
    }

    private var newNoteComposer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Note")
                .font(.headline)
            TextEditor(text: $newNoteText)
                .frame(minHeight: 80)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

            Toggle("Use current timestamp", isOn: $useCurrentTimestamp.animation())
                .font(.caption)
            if !useCurrentTimestamp {
                DatePicker("Timestamp", selection: $manualTimestamp, displayedComponents: [.date, .hourAndMinute])
            }

            HStack {
                Spacer()
                Button("Add Note") {
                    appendNewNote()
                }
                .disabled(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Attachments")
                    .font(.headline)
                Spacer()
                Button {
                    showBookmarkImporter = true
                } label: {
                    Label("Link File", systemImage: "link")
                }
                Button {
                    showCopyImporter = true
                } label: {
                    Label("Import Copy", systemImage: "square.and.arrow.down")
                }
            }

            if attachmentDrafts.isEmpty {
                Text("No attachments yet. Link a file or import a copy to keep artifacts nearby.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(sortedAttachments) { attachment in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(attachment.fileName)
                                    .font(.subheadline)
                                    .bold()
                                Spacer()
                                Menu {
                                    if attachment.bookmarkData != nil {
                                        Button("Open Linked File") {
                                            openBookmark(attachment)
                                        }
                                    }
                                    if let path = attachment.storedRelativePath {
                                        Button("Reveal in Finder") {
                                            revealStoredCopy(relativePath: path)
                                        }
                                    }
                                    Button(role: .destructive) {
                                        removeAttachment(attachment)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                            }
                            HStack(spacing: 8) {
                                if let size = attachment.fileSize {
                                    Text(formatFileSize(size))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text("Added \(formattedDate(attachment.createdAt))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(12)
                        .background(cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2))
                        )
                    }
                }
            }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading) {
            Text("Tags (comma-separated)").font(.caption)
            TextField("e.g., urgent, client-X, refactor", text: $tagInput)
                .textFieldStyle(.roundedBorder)

            let suggestions = TagSuggestions.allTagNames(modelContext: ctx)
            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(suggestions, id: \.self) { s in
                            Button {
                                appendTag(s)
                            } label: {
                                Text(s).font(.caption)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack {
            Spacer()
            Button("Cancel") {
                cleanupPendingCopies()
                if isNew { ctx.delete(task) }
                dismiss()
            }
            Button("Save") {
                persistChanges()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var sortedNotes: [NoteDraft] {
        noteDrafts.sorted { $0.position < $1.position }
    }

    private var sortedAttachments: [AttachmentDraft] {
        attachmentDrafts.sorted { $0.position < $1.position }
    }

    private func appendNewNote() {
        let trimmed = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let timestamp = useCurrentTimestamp ? Date() : manualTimestamp
        let nextPosition = (noteDrafts.map { $0.position }.max() ?? -1) + 1
        noteDrafts.append(NoteDraft(id: UUID(), text: trimmed, createdAt: timestamp, position: nextPosition))
        newNoteText = ""
        useCurrentTimestamp = true
        manualTimestamp = Date()
    }

    private func removeNote(_ draft: NoteDraft) {
        noteDrafts.removeAll { $0.id == draft.id }
        reindexNotes()
    }

    private func reindexNotes() {
        noteDrafts = noteDrafts.sorted { $0.position < $1.position }.enumerated().map { index, element in
            var updated = element
            updated.position = index
            return updated
        }
    }

    private func removeAttachment(_ attachment: AttachmentDraft) {
        attachmentDrafts.removeAll { $0.id == attachment.id }
        if let path = attachment.storedRelativePath, pendingCopyPaths.contains(path) {
            deleteStoredCopy(relativePath: path)
            pendingCopyPaths.remove(path)
        }
        reindexAttachments()
    }

    private func reindexAttachments() {
        attachmentDrafts = attachmentDrafts.sorted { $0.position < $1.position }.enumerated().map { index, element in
            var updated = element
            updated.position = index
            return updated
        }
    }

    private func persistChanges() {
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.status = status
        task.dueDate = dueDateEnabled ? dueDate : nil

        let tags = TagSuggestions.ensureTags(from: tagInput, in: ctx)
        task.tags = tags

        task.notes.forEach { ctx.delete($0) }
        task.notes = []
        for (index, draft) in sortedNotes.enumerated() {
            let note = TaskWorkNote(text: draft.text,
                                    createdAt: draft.createdAt,
                                    position: index,
                                    task: task)
            task.notes.append(note)
        }

        task.attachments.forEach { ctx.delete($0) }
        task.attachments = []
        for (index, draft) in sortedAttachments.enumerated() {
            let attachment = TaskAttachment(fileName: draft.fileName,
                                            contentType: draft.contentType,
                                            fileSize: draft.fileSize,
                                            bookmarkData: draft.bookmarkData,
                                            storedRelativePath: draft.storedRelativePath,
                                            createdAt: draft.createdAt,
                                            position: index,
                                            task: task)
            task.attachments.append(attachment)
        }

        pendingCopyPaths.removeAll()
        try? ctx.save()
        onSave(task)
        dismiss()
    }

    private func cleanupPendingCopies() {
        for path in pendingCopyPaths {
            deleteStoredCopy(relativePath: path)
        }
        pendingCopyPaths.removeAll()
    }

    private func handleBookmarkImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let bookmark = try url.bookmarkData(options: [.withSecurityScope],
                                                    includingResourceValuesForKeys: nil,
                                                    relativeTo: nil)
                let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey, .fileSizeKey])
                let size = resourceValues.fileSize
                let contentType = resourceValues.contentType?.identifier
                let nextPosition = (attachmentDrafts.map { $0.position }.max() ?? -1) + 1
                attachmentDrafts.append(AttachmentDraft(id: UUID(),
                                                        fileName: url.lastPathComponent,
                                                        contentType: contentType,
                                                        fileSize: size,
                                                        bookmarkData: bookmark,
                                                        storedRelativePath: nil,
                                                        createdAt: Date(),
                                                        position: nextPosition))
            } catch {
                alertMessage = IdentifiableMessage(message: error.localizedDescription)
            }
        case .failure(let error):
            alertMessage = IdentifiableMessage(message: error.localizedDescription)
        }
    }

    private func handleCopyImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let destination = try copyIntoApplicationSupport(url: url)
                let relativePath = try relativePathInAppSupport(for: destination)
                let resourceValues = try destination.resourceValues(forKeys: [.contentTypeKey, .fileSizeKey])
                let size = resourceValues.fileSize
                let contentType = resourceValues.contentType?.identifier
                let nextPosition = (attachmentDrafts.map { $0.position }.max() ?? -1) + 1
                attachmentDrafts.append(AttachmentDraft(id: UUID(),
                                                        fileName: destination.lastPathComponent,
                                                        contentType: contentType,
                                                        fileSize: size,
                                                        bookmarkData: nil,
                                                        storedRelativePath: relativePath,
                                                        createdAt: Date(),
                                                        position: nextPosition))
                pendingCopyPaths.insert(relativePath)
            } catch {
                alertMessage = IdentifiableMessage(message: error.localizedDescription)
            }
        case .failure(let error):
            alertMessage = IdentifiableMessage(message: error.localizedDescription)
        }
    }

    private func copyIntoApplicationSupport(url: URL) throws -> URL {
        let fm = FileManager.default
        let appSupport = try fm.url(for: .applicationSupportDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true)
        let attachmentsDirectory = appSupport.appendingPathComponent("Attachments", isDirectory: true)
        if !fm.fileExists(atPath: attachmentsDirectory.path) {
            try fm.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)
        }

        let uniqueName = uniqueFileName(basename: url.lastPathComponent, in: attachmentsDirectory)
        let destination = attachmentsDirectory.appendingPathComponent(uniqueName, isDirectory: false)
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: url, to: destination)
        return destination
    }

    private func relativePathInAppSupport(for url: URL) throws -> String {
        let fm = FileManager.default
        let appSupport = try fm.url(for: .applicationSupportDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true)
        let path = url.path
        let base = appSupport.path
        guard path.hasPrefix(base) else {
            throw NSError(domain: "TaskEditor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Attachment copy is outside the Application Support directory."])
        }
        let trimmed = String(path.dropFirst(base.count))
        return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func deleteStoredCopy(relativePath: String) {
        do {
            let fm = FileManager.default
            let appSupport = try fm.url(for: .applicationSupportDirectory,
                                        in: .userDomainMask,
                                        appropriateFor: nil,
                                        create: true)
            let target = appSupport.appendingPathComponent(relativePath)
            if fm.fileExists(atPath: target.path) {
                try fm.removeItem(at: target)
            }
        } catch {
            // Ignore cleanup failures but surface if debugging is needed
        }
    }

    private func openBookmark(_ attachment: AttachmentDraft) {
        guard let bookmark = attachment.bookmarkData else { return }
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmark,
                              options: [.withSecurityScope],
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)
            let _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #else
            alertMessage = IdentifiableMessage(message: "Opening linked files is currently supported on macOS builds.")
            #endif
        } catch {
            alertMessage = IdentifiableMessage(message: error.localizedDescription)
        }
    }

    private func revealStoredCopy(relativePath: String) {
        do {
            let fm = FileManager.default
            let appSupport = try fm.url(for: .applicationSupportDirectory,
                                        in: .userDomainMask,
                                        appropriateFor: nil,
                                        create: true)
            let target = appSupport.appendingPathComponent(relativePath)
            guard fm.fileExists(atPath: target.path) else {
                throw NSError(domain: "TaskEditor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Stored copy is missing. It may have been moved or deleted."])
            }
            #if os(macOS)
            NSWorkspace.shared.activateFileViewerSelecting([target])
            #else
            alertMessage = IdentifiableMessage(message: "Revealing stored copies is currently supported on macOS builds.")
            #endif
        } catch {
            alertMessage = IdentifiableMessage(message: error.localizedDescription)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        TaskEditorView.timelineFormatter.string(from: date)
    }

    private func formatFileSize(_ size: Int) -> String {
        TaskEditorView.fileSizeFormatter.string(fromByteCount: Int64(size))
    }

    private func uniqueFileName(basename: String, in directory: URL) -> String {
        let fm = FileManager.default
        var attempt = 0
        let baseName = basename
        var candidate = baseName
        while fm.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            attempt += 1
            let name = (baseName as NSString).deletingPathExtension
            let ext = (baseName as NSString).pathExtension
            if ext.isEmpty {
                candidate = "\(name)-\(attempt)"
            } else {
                candidate = "\(name)-\(attempt).\(ext)"
            }
        }
        return candidate
    }

    private func appendTag(_ s: String) {
        var set = Set(tagInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
        set.insert(s)
        tagInput = Array(set).sorted().joined(separator: ", ")
    }

    private struct NoteDraft: Identifiable, Hashable {
        var id: UUID
        var text: String
        var createdAt: Date
        var position: Int
    }

    private struct AttachmentDraft: Identifiable, Hashable {
        var id: UUID
        var fileName: String
        var contentType: String?
        var fileSize: Int?
        var bookmarkData: Data?
        var storedRelativePath: String?
        var createdAt: Date
        var position: Int
    }

    private struct IdentifiableMessage: Identifiable {
        let id = UUID()
        let message: String
    }

    private static let timelineFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let fileSizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    private var cardBackground: Color {
        #if os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #elseif canImport(UIKit)
        return Color(uiColor: .secondarySystemBackground)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }
}
