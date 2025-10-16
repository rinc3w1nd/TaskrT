import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Task.dueDate, order: .forward, animation: .easeInOut) private var tasks: [Task]

    @State private var showEditor = false
    @State private var filterStatus: TaskStatus? = .pending
    @State private var searchText = ""
    @State private var selectedTags: Set<String> = []

    var body: some View {
        NavigationView {
            VStack {
                // Filters
                HStack {
                    Picker("Status", selection: Binding(
                        get: { filterStatus ?? .pending },
                        set: { filterStatus = $0 }
                    )) {
                        Text("Pending").tag(TaskStatus.pending)
                        Text("Done").tag(TaskStatus.done)
                        Text("Canceled").tag(TaskStatus.canceled)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)

                    Spacer()

                    Menu("Tags") {
                        let suggestions = TagSuggestions.allTagNames(modelContext: ctx)
                        ForEach(suggestions, id: \.self) { tag in
                            let isOn = selectedTags.contains(tag)
                            Button {
                                if isOn { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
                            } label: {
                                Label(tag, systemImage: isOn ? "checkmark.circle.fill" : "circle")
                            }
                        }
                        if !selectedTags.isEmpty {
                            Divider()
                            Button("Clear Tag Filter") { selectedTags.removeAll() }
                        }
                    }
                }
                .padding(.horizontal)

                // Search
                TextField("Search title/notes…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding([.horizontal, .bottom])

                // List
                List(filtered(tasks)) { task in
                    HStack(alignment: .firstTextBaseline) {
                        Circle()
                            .fill(colorForTask(task))
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title).bold()
                            HStack(spacing: 6) {
                                if let d = task.dueDate {
                                    Text(d, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("No due date")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if !task.tags.isEmpty {
                                    Text("•").foregroundColor(.secondary)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 4) {
                                            ForEach(task.tags, id: \.self) { tag in
                                                Text(tag.name)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                                    .background(Color.gray.opacity(0.15))
                                                    .cornerRadius(4)
                                            }
                                        }
                                    }.frame(height: 16)
                                }
                            }
                            if !task.notes.isEmpty {
                                Text(task.notes).font(.caption).lineLimit(1).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Menu {
                            Button("Mark Done") { withAnimation { task.status = .done; NotificationManager.cancelNotifications(for: task) } }
                            Button("Cancel") { withAnimation { task.status = .canceled; NotificationManager.cancelNotifications(for: task) } }
                            Divider()
                            Button("Edit…") { showEditor = true; edit(task) }
                            Button(role: .destructive, action: { delete(task) }) { Text("Delete") }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button("Edit…") { showEditor = true; edit(task) }
                        Button("Mark Done") { task.status = .done; NotificationManager.cancelNotifications(for: task) }
                    }
                }
                .listStyle(.inset)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newTask()
                    } label: {
                        Label("New Task", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                if let draft = draftTask {
                    TaskEditorView(task: draft, isNew: isNewDraft) { saved in
                        switch saved.status {
                        case .pending:
                            if saved.dueDate != nil {
                                NotificationManager.scheduleNotifications(for: saved)
                            } else {
                                NotificationManager.cancelNotifications(for: saved)
                            }
                        default:
                            NotificationManager.cancelNotifications(for: saved)
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("NEW_TASK_SHORTCUT"))) { _ in
                newTask()
            }
            .navigationTitle("Tasks")
        }
    }

    // MARK: Draft management
    @State private var draftTask: Task?
    @State private var isNewDraft = true

    private func newTask() {
        let t = Task(title: "")
        isNewDraft = true
        draftTask = t
        showEditor = true
        ctx.insert(t)
    }

    private func edit(_ t: Task) {
        isNewDraft = false
        draftTask = t
    }

    private func delete(_ t: Task) {
        NotificationManager.cancelNotifications(for: t)
        ctx.delete(t)
    }

    // MARK: Filtering/search
    private func filtered(_ tasks: [Task]) -> [Task] {
        tasks
            .filter { t in
                if let fs = filterStatus, t.status != fs { return false }
                if !selectedTags.isEmpty {
                    let names = Set(t.tags.map { $0.name })
                    if selectedTags.intersection(names).isEmpty { return false }
                }
                if !searchText.isEmpty {
                    let q = searchText.lowercased()
                    if !(t.title.lowercased().contains(q) || t.notes.lowercased().contains(q)) {
                        return false
                    }
                }
                return true
            }
            .sorted { lhs, rhs in
                // Sort by "time left to due" (pending first, undated last)
                switch (lhs.dueDate, rhs.dueDate) {
                case let (l?, r?): return l < r
                case (_?, nil):   return true
                case (nil, _?):   return false
                default:          return lhs.createdAt < rhs.createdAt
                }
            }
    }
}