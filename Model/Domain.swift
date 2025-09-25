import Foundation

#if canImport(SwiftUI)
    import SwiftUI
#endif

struct TaskItem: Identifiable, Codable, Equatable {
    enum Status: String, Codable, CaseIterable, Identifiable {
        case todo
        case doing
        case done

        var id: String { rawValue }

        var displayName: String {
            switch self {
                case .todo: "Todo"
                case .doing: "Doing"
                case .done: "Done"
            }
        }

        var sortOrder: Int {
            switch self {
                case .todo: 0
                case .doing: 1
                case .done: 2
            }
        }
    }

    let id: UUID
    var title: String
    var status: Status
    var dueDate: Date?
    var note: String?

    var isDone: Bool {
        status == .done
    }

    init(
        id: UUID = UUID(),
        title: String,
        status: Status = .todo,
        dueDate: Date? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.dueDate = dueDate
        self.note = note
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case status
        case dueDate
        case due
        case note
        case isDone
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""

        if let decodedStatus = try container.decodeIfPresent(Status.self, forKey: .status) {
            status = decodedStatus
        } else if let legacyDone = try container.decodeIfPresent(Bool.self, forKey: .isDone) {
            status = legacyDone ? .done : .todo
        } else {
            status = .todo
        }

        if let decodedDueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate) {
            dueDate = decodedDueDate
        } else {
            dueDate = try container.decodeIfPresent(Date.self, forKey: .due)
        }

        note = try container.decodeIfPresent(String.self, forKey: .note)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(isDone, forKey: .isDone)
    }
}

@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [TaskItem]

    private let storageURL: URL
    private let environment: [String: String]
    private var calendar: Calendar

    init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.environment = environment
        storageURL = TaskStore.makeStorageURL(fileManager: fileManager)

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.firstWeekday = 2
        self.calendar = calendar

        tasks = TaskStore.loadTasks(from: storageURL) ?? []
        applySeedIfNeeded()
        saveIfNeeded()
    }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tasks.insert(TaskItem(title: trimmed), at: 0)
        saveIfNeeded()
    }

    func toggle(_ id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].status = tasks[index].status == .done ? .todo : .done
        saveIfNeeded()
    }

    func updateStatus(for id: UUID, to status: TaskItem.Status) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].status = status
        saveIfNeeded()
    }

    func updateDueDate(for id: UUID, to dueDate: Date?) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].dueDate = dueDate
        saveIfNeeded()
    }

    func remove(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
        saveIfNeeded()
    }

    func tasks(with status: TaskItem.Status) -> [TaskItem] {
        tasks.filter { $0.status == status }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func tasks(on date: Date) -> [TaskItem] {
        tasks.filter { item in
            guard let dueDate = item.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: date)
        }
        .sorted { lhs, rhs in
            if lhs.status == rhs.status {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.status.sortOrder < rhs.status.sortOrder
        }
    }

    var allTasks: [TaskItem] {
        tasks
    }

    private func applySeedIfNeeded() {
        let seeds = TaskItem.debugSeed(reference: Date(), calendar: calendar)
        if shouldForceSeed {
            tasks = seeds
        } else if tasks.isEmpty {
            tasks = seeds
        } else {
            let existingIDs = Set(tasks.map(\.id))
            let missing = seeds.filter { !existingIDs.contains($0.id) }
            guard !missing.isEmpty else { return }
            tasks.append(contentsOf: missing)
        }
    }

    private func saveIfNeeded() {
        guard shouldPersist else { return }
        do {
            let data = try JSONEncoder().encode(tasks)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("⚠️ Failed to save tasks: \(error)")
        }
    }

    private var shouldPersist: Bool {
        environment["TASKS_DISABLE_PERSISTENCE"] != "1"
    }

    private var shouldForceSeed: Bool {
        environment["TASKS_FORCE_SEED"] == "1"
    }

    private static func makeStorageURL(fileManager: FileManager) -> URL {
        let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return directory.appendingPathComponent("tasks.json")
    }

    private static func loadTasks(from url: URL) -> [TaskItem]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode([TaskItem].self, from: data)
        } catch {
            print("⚠️ Failed to decode tasks: \(error)")
            return nil
        }
    }
}

extension TaskItem {
    static func debugSeed(
        reference: Date = Date(),
        calendar inputCalendar: Calendar = Calendar(identifier: .gregorian)
    ) -> [TaskItem] {
        var calendar = inputCalendar
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone.current

        let today = calendar.startOfDay(for: reference)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)
        let friday = calendar.nextDate(
            after: today,
            matching: DateComponents(weekday: 6),
            matchingPolicy: .nextTimePreservingSmallerComponents
        ) ?? today

        return [
            TaskItem(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
                title: "仕様確認",
                status: .todo,
                dueDate: tomorrow
            ),
            TaskItem(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(),
                title: "API実装",
                status: .doing,
                dueDate: today
            ),
            TaskItem(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID(),
                title: "コードレビュー",
                status: .done,
                dueDate: yesterday
            ),
            TaskItem(
                id: UUID(uuidString: "44444444-4444-4444-4444-444444444444") ?? UUID(),
                title: "週次ミーティング",
                status: .todo,
                dueDate: friday
            ),
            TaskItem(
                id: UUID(uuidString: "55555555-5555-5555-5555-555555555555") ?? UUID(),
                title: "バックログ整理",
                status: .doing,
                dueDate: calendar.date(byAdding: .day, value: 3, to: today)
            )
        ]
    }
}
