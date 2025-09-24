import CoreData
import SwiftUI

struct TaskListView: View {
    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Task.dueDate, ascending: true),
            NSSortDescriptor(keyPath: \Task.createdAt, ascending: true),
        ],
        animation: .default
    )
    private var tasks: FetchedResults<Task>

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        NavigationStack {
            List {
                ForEach(tasks) { task in
                    TaskRow(task: task, dateFormatter: dateFormatter)
                        .frame(minHeight: 56)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if task.taskStatus != .done {
                                Button("Complete") {
                                    update(task) { $0.taskStatus = .done }
                                }
                                .tint(.green)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                delete(task)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                .onDelete(perform: delete)
            }
            .listStyle(.plain)
            .navigationTitle("Synapse Tasks")
        }
    }

    private func update(_ task: Task, changes: (Task) -> Void) {
        changes(task)
        persistChanges()
    }

    private func delete(_ task: Task) {
        context.delete(task)
        persistChanges()
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { tasks[$0] }.forEach(context.delete)
        persistChanges()
    }

    private func persistChanges() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to save context: \(error)")
        }
    }

    private func addTask(title: String) {
        let newTask = TaskEntity(context: context)
        newTask.id = UUID()
        newTask.title = title
        newTask.status = "todo"
        newTask.priority = 3
        newTask.createdAt = Date()
        newTask.updatedAt = Date()

        persistChanges()
    }
}

private struct TaskRow: View {
    @ObservedObject var task: Task
    let dateFormatter: DateFormatter

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            statusIndicator
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                HStack(spacing: 12) {
                    if let dueDate = task.dueDate {
                        Label(dateFormatter.string(from: dueDate), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Label(task.taskStatus.displayName, systemImage: statusIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            priorityBadge
        }
        .padding(.vertical, 8)
    }

    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
    }

    private var statusColor: Color {
        switch task.taskStatus {
        case .todo: .blue
        case .doing: .orange
        case .done: .green
        }
    }

    private var statusIcon: String {
        switch task.taskStatus {
        case .todo: "square"
        case .doing: "clock"
        case .done: "checkmark.circle"
        }
    }

    private var priorityBadge: some View {
        Text("P\(task.priority)")
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.gray.opacity(0.2)))
    }
}
