import Foundation
import SwiftUI

struct TaskItem: Identifiable, Codable, Hashable {
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

        var accentColor: Color {
            switch self {
                case .todo: .gray
                case .doing: .blue
                case .done: .green
            }
        }

        var displayOrder: Int {
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

    var isDone: Bool {
        get { status == .done }
        set { status = newValue ? .done : (status == .done ? .todo : status) }
    }

    init(
        id: UUID = .init(),
        title: String,
        status: Status = .todo,
        dueDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.dueDate = dueDate
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case status
        case dueDate
        case isDone
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)

        if let decodedStatus = try container.decodeIfPresent(Status.self, forKey: .status) {
            status = decodedStatus
        } else {
            let legacyDone = try container.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
            status = legacyDone ? .done : .todo
        }

        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encode(isDone, forKey: .isDone)
    }
}

@MainActor
final class TaskStore: ObservableObject {
    @Published var items: [TaskItem] = [] { didSet { saveIfNeeded() } }

    private let key = "tasks.v1"
    private let environment = ProcessInfo.processInfo.environment

    init() {
        load()
        // Envに従ってデバッグシード投入（Releaseでも許可）
        if shouldForceSeed {
            applyDebugSeed(overwriting: true)
        } else if items.isEmpty {
            applyDebugSeed(overwriting: false)
        }
    }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.insert(TaskItem(title: trimmed), at: 0)
    }

    func toggle(_ id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].status = items[index].status == .done ? .todo : .done
        }
    }

    func updateStatus(for id: UUID, to status: TaskItem.Status) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = status
    }

    func updateDueDate(for id: UUID, to dueDate: Date?) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].dueDate = dueDate
    }

    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    func tasks(with status: TaskItem.Status) -> [TaskItem] {
        items.filter { $0.status == status }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func tasks(on date: Date, calendar: Calendar = .current) -> [TaskItem] {
        items.filter { item in
            guard let dueDate = item.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: date)
        }
        .sorted { lhs, rhs in
            if lhs.status == rhs.status {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.status.displayOrder < rhs.status.displayOrder
        }
    }

    private func saveIfNeeded() {
        guard shouldPersist else { return }
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) else { return }
        items = decoded
    }

    private var shouldPersist: Bool {
        environment["TASKS_DISABLE_PERSISTENCE"] != "1"
    }

    private var shouldForceSeed: Bool {
        environment["TASKS_FORCE_SEED"] == "1"
    }

    private func applyDebugSeed(overwriting: Bool) {
        let seedItems = TaskItem.debugSeed()
        if overwriting {
            items = seedItems
        } else {
            let existingIDs = Set(items.map(\.id))
            let merged = seedItems.filter { !existingIDs.contains($0.id) }
            guard !merged.isEmpty else { return }
            items.append(contentsOf: merged)
        }
    }
}

#if DEBUG
    extension TaskItem {
        static func debugSeed(reference: Date = Date(), calendar inputCalendar: Calendar = .current) -> [TaskItem] {
            var calendar = inputCalendar
            calendar.locale = Locale(identifier: "ja_JP")
            calendar.timeZone = TimeZone.current
            let today = calendar.startOfDay(for: reference)

            let previousDay = calendar.date(byAdding: .day, value: -1, to: today)
            let friday = calendar.nextDate(
                after: today,
                matching: DateComponents(weekday: 6),
                matchingPolicy: .nextTimePreservingSmallerComponents
            ) ?? today
            let nextWeekPlanning = calendar.date(byAdding: .day, value: 3, to: today)

            let definitions: [(uuid: UUID, title: String, status: TaskItem.Status, date: Date?)] = [
                (UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(), "仕様確認", .todo, nil),
                (UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(), "API実装", .doing, today),
                (UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID(), "コードレビュー", .done, previousDay),
                (UUID(uuidString: "44444444-4444-4444-4444-444444444444") ?? UUID(), "週次ミーティング", .todo, friday),
                (
                    UUID(uuidString: "55555555-5555-5555-5555-555555555555") ?? UUID(),
                    "バックログ整理",
                    .doing,
                    nextWeekPlanning
                )
            ]

            return definitions.map { definition in
                TaskItem(
                    id: definition.uuid,
                    title: definition.title,
                    status: definition.status,
                    dueDate: definition.date
                )
            }
        }
    }
#endif
