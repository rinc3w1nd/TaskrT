import SwiftUI
import SwiftData

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    @State var title: String
    @State var notes: String
    @State var dueDateEnabled: Bool
    @State var dueDate: Date
    @State var tagInput: String
    @State var status: TaskStatus

    let isNew: Bool
    let onSave: (Task) -> Void

    private var task: Task

    init(task: Task, isNew: Bool, onSave: @escaping (Task) -> Void) {
        self.task = task
        self._title = State(initialValue: task.title)
        self._notes = State(initialValue: task.notes)
        self._dueDateEnabled = State(initialValue: task.dueDate != nil)
        self._dueDate = State(initialValue: task.dueDate ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
        self._tagInput = State(initialValue: task.tags.map { $0.name }.joined(separator: ", "))
        self._status = State(initialValue: task.status)
        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isNew ? "New Task" : "Edit Task")
                .font(.title2).bold()

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $notes)
                .frame(minHeight: 80)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

            Toggle("Has due date", isOn: $dueDateEnabled.animation())
            if dueDateEnabled {
                DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
            }

            VStack(alignment: .leading) {
                Text("Tags (comma-separated)").font(.caption)
                TextField("e.g., urgent, client-X, refactor", text: $tagInput)
                    .textFieldStyle(.roundedBorder)

                // Suggestions
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

            Picker("Status", selection: $status) {
                ForEach(TaskStatus.allCases) { s in
                    Text(s.rawValue.capitalized).tag(s)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Spacer()
                Button("Cancel") {
                    if isNew { ctx.delete(task) }
                    dismiss()
                }
                Button("Save") {
                    task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    task.notes = notes
                    task.status = status
                    task.dueDate = dueDateEnabled ? dueDate : nil

                    // Update tags
                    let tags = TagSuggestions.ensureTags(from: tagInput, in: ctx)
                    task.tags = tags

                    try? ctx.save()
                    onSave(task)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 560)
    }

    private func appendTag(_ s: String) {
        var set = Set(tagInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
        set.insert(s)
        tagInput = Array(set).sorted().joined(separator: ", ")
    }
}