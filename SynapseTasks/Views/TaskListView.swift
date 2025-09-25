import SwiftUI

struct TaskListView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case list
        case board
        case weekly

        var id: String { rawValue }

        var label: String {
            switch self {
                case .list: "リスト"
                case .board: "ボード"
                case .weekly: "週間"
            }
        }
    }

    @EnvironmentObject private var store: TaskStore
    @State private var newTitle = ""
    @State private var selectedTab: Tab
    @State private var selectedDate: Date

    private let calendar: Calendar

    init(
        initialTab: Tab = .list,
        initialWeeklyDate: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) {
        _selectedTab = State(initialValue: initialTab)
        let startOfDay = calendar.startOfDay(for: initialWeeklyDate)
        _selectedDate = State(initialValue: startOfDay)
        var calendarCopy = calendar
        calendarCopy.locale = Locale(identifier: "ja_JP")
        calendarCopy.firstWeekday = 2
        self.calendar = calendarCopy
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("ビュー", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.label).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .navigationTitle("Synapse Tasks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if selectedTab == .list {
                        EditButton()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
            case .list:
                listView
            case .board:
                boardView
            case .weekly:
                weeklyView
        }
    }

    private var listView: some View {
        List {
            Section {
                HStack {
                    TextField("新しいタスク", text: $newTitle)
                        .textInputAutocapitalization(.never)
                    Button("追加") {
                        store.add(newTitle)
                        newTitle = ""
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section {
                if store.items.isEmpty {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("ここにタスクが一覧表示されます（DebugシードはTASKS_FORCE_SEED=1）")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(store.items) { item in
                        HStack(spacing: 12) {
                            Button(action: { store.toggle(item.id) }) {
                                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isDone ? .green : .secondary)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .strikethrough(item.isDone)
                                    .foregroundStyle(item.isDone ? .secondary : .primary)
                                if let dueDate = item.dueDate {
                                    Text(dueDate, formatter: DateFormatter.short)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: store.remove)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var boardView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 20) {
                ForEach(TaskItem.Status.allCases.sorted(by: { $0.displayOrder < $1.displayOrder })) { status in
                    boardColumn(for: status)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func boardColumn(for status: TaskItem.Status) -> some View {
        let tasks = store.tasks(with: status)

        return VStack(alignment: .leading, spacing: 12) {
            Label(status.displayName, systemImage: iconName(for: status))
                .font(.headline)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(status.accentColor.opacity(0.15), in: Capsule())

            if tasks.isEmpty, store.items.isEmpty, status == .todo {
                Text("ボードは空です。タスクを追加して列に振り分けましょう")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
            } else if tasks.isEmpty {
                Text("タスクはありません")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
            } else {
                VStack(spacing: 12) {
                    ForEach(tasks) { item in
                        boardCard(for: item)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 240, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func boardCard(for item: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(item.status.accentColor)
                    .frame(width: 10, height: 10)
                    .padding(.top, 6)

                Text(item.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let dueDate = item.dueDate {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(dueDate, formatter: DateFormatter.medium)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
        .contextMenu {
            ForEach(TaskItem.Status.allCases.sorted(by: { $0.displayOrder < $1.displayOrder })) { status in
                Button {
                    store.updateStatus(for: item.id, to: status)
                } label: {
                    if status == item.status {
                        Label(status.displayName, systemImage: "checkmark")
                    } else {
                        Text(status.displayName)
                    }
                }
            }
        }
    }

    private var weeklyView: some View {
        let tasks = store.tasks(on: selectedDate, calendar: calendar)

        return VStack(alignment: .leading, spacing: 16) {
            weekdayChips

            Text(dateTitle(for: selectedDate))
                .font(.title3.bold())

            if tasks.isEmpty {
                Text("この日はまだ予定がありません")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(tasks) { item in
                        HStack(spacing: 12) {
                            Capsule()
                                .fill(item.status.accentColor)
                                .frame(width: 6, height: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .fontWeight(.semibold)
                                Text(item.status.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 6, y: 3)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var weekdayChips: some View {
        let week = currentWeek()

        return HStack(spacing: 8) {
            ForEach(week, id: \.self) { date in
                Button {
                    selectedDate = date
                } label: {
                    VStack(spacing: 4) {
                        Text(shortWeekdaySymbol(for: date))
                            .font(.footnote)
                        Text("\(calendar.component(.day, from: date))")
                            .font(.subheadline.bold())
                    }
                    .frame(width: 48, height: 48)
                    .background(chipBackground(for: date))
                    .foregroundStyle(chipForeground(for: date))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func currentWeek() -> [Date] {
        guard let weekStart = calendar.date(from: calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: selectedDate
        )) else {
            return []
        }
        return (0 ..< 7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
    }

    private func iconName(for status: TaskItem.Status) -> String {
        switch status {
            case .todo: "tray"
            case .doing: "hammer"
            case .done: "checkmark.circle"
        }
    }

    private func shortWeekdaySymbol(for date: Date) -> String {
        let weekday = calendar.component(.weekday, from: date)
        let symbols = ["日", "月", "火", "水", "木", "金", "土"]
        return symbols[(weekday - 1 + symbols.count) % symbols.count]
    }

    private func chipBackground(for date: Date) -> Color {
        calendar.isDate(date, inSameDayAs: selectedDate) ? Color.accentColor.opacity(0.2) : Color(.systemBackground)
    }

    private func chipForeground(for date: Date) -> Color {
        calendar.isDate(date, inSameDayAs: selectedDate) ? .accentColor : .primary
    }

    private func dateTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d(E)"
        return formatter.string(from: date)
    }
}

private extension DateFormatter {
    static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    static let medium: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
