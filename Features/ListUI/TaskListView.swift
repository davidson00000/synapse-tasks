import SwiftUI

// swiftlint:disable type_body_length
struct TaskListView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case list
        case board
        case week

        var id: String { rawValue }

        var label: String {
            switch self {
                case .list: "リスト"
                case .board: "ボード"
                case .week: "週間"
            }
        }
    }

    @EnvironmentObject private var store: TaskStore
    #if DEBUG
        @EnvironmentObject private var router: AppRouter
    #endif
    @State private var newTitle = ""
    @State private var selectedTab: Tab = .list
    @State private var selectedDate = Date()

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.firstWeekday = 2
        return calendar
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("ビュー", selection: tabSelectionBinding) {
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
        }
        #if DEBUG
        .onAppear(perform: syncRouterToState)
            .onReceive(router.$selectedTab) { _ in
                syncRouterToState()
            }
            .onReceive(router.$selectedWeekday) { _ in
                syncRouterToState()
            }
        #endif
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
            case .list:
                listView
            case .board:
                boardView
            case .week:
                weeklyView
        }
    }

    private var listView: some View {
        List {
            Section(header: Text("タスク追加")) {
                HStack(spacing: 12) {
                    TextField("新しいタスク", text: $newTitle)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    Button(action: addTask) {
                        Label("追加", systemImage: "plus.circle.fill")
                            .labelStyle(.iconOnly)
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.borderless)
                }
            }

            Section(header: Text("すべてのタスク")) {
                if store.allTasks.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("ここにはタスク一覧が表示されます。デバッグ時は TASKS_FORCE_SEED=1 で初期データが投入されます。")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                } else {
                    ForEach(store.allTasks) { task in
                        HStack(spacing: 12) {
                            Button(action: {
                                store.toggle(task.id)
                            }, label: {
                                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.isDone ? .green : .secondary)
                                    .imageScale(.large)
                            })
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(.headline)
                                    .foregroundStyle(task.isDone ? .secondary : .primary)
                                    .strikethrough(task.isDone)
                                if let dueDate = task.dueDate {
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
                ForEach(TaskItem.Status.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })) { status in
                    boardColumn(for: status)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func boardColumn(for status: TaskItem.Status) -> some View {
        let tasks = store.tasks(with: status)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color(for: status))
                    .frame(width: 12, height: 12)
                Text(status.displayName)
                    .font(.headline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color(for: status).opacity(0.15), in: Capsule())

            if tasks.isEmpty {
                Text(emptyMessage(for: status))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
            } else {
                VStack(spacing: 12) {
                    ForEach(tasks) { task in
                        boardCard(for: task)
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

    private func boardCard(for task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(task.title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let dueDate = task.dueDate {
                Label(dueDate, formatter: DateFormatter.medium)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
        .contextMenu {
            ForEach(TaskItem.Status.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })) { status in
                Button(action: {
                    store.updateStatus(for: task.id, to: status)
                }, label: {
                    if status == task.status {
                        Label(status.displayName, systemImage: "checkmark")
                    } else {
                        Text(status.displayName)
                    }
                })
            }
        }
    }

    private var weeklyView: some View {
        VStack(alignment: .leading, spacing: 20) {
            weekdayChips
            Divider()
            Text(dateTitle(for: selectedDate))
                .font(.title3.bold())

            let tasks = store.tasks(on: selectedDate)
            if tasks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("この日はまだタスクが登録されていません。ボードやリストで予定を追加してみましょう。")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(tasks) { task in
                        HStack(spacing: 12) {
                            Capsule()
                                .fill(color(for: task.status))
                                .frame(width: 6, height: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(.headline)
                                Text(task.status.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                        )
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
        let week = currentWeek(containing: selectedDate)
        return HStack(spacing: 8) {
            ForEach(week, id: \.self) { date in
                Button(action: {
                    selectedDate = date
                    #if DEBUG
                        router.selectedWeekday = weekdayCode(for: date)
                    #endif
                }, label: {
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
                })
                .buttonStyle(.plain)
            }
        }
    }

    private func addTask() {
        store.add(newTitle)
        newTitle = ""
    }

    private func currentWeek(containing date: Date) -> [Date] {
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([
            .yearForWeekOfYear,
            .weekOfYear
        ], from: date)) else {
            return []
        }
        return (0 ..< 7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfWeek)
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

    private func color(for status: TaskItem.Status) -> Color {
        switch status {
            case .todo: .blue
            case .doing: .orange
            case .done: .green
        }
    }

    private func emptyMessage(for status: TaskItem.Status) -> String {
        switch status {
            case .todo:
                "Todo 列は空です。新しいタスクを追加して計画を立てましょう。"
            case .doing:
                "Doing 列には進行中のタスクが表示されます。ステータスを切り替えてみてください。"
            case .done:
                "Done 列は完了したタスクが並びます。達成した項目はここで振り返りましょう。"
        }
    }

    private var tabSelectionBinding: Binding<Tab> {
        #if DEBUG
            Binding(
                get: { selectedTab },
                set: { newValue in
                    selectedTab = newValue
                    router.selectedTab = newValue.rawValue
                }
            )
        #else
            Binding(
                get: { selectedTab },
                set: { selectedTab = $0 }
            )
        #endif
    }

    #if DEBUG
        private func syncRouterToState() {
            if let tab = Tab(rawValue: router.selectedTab) {
                selectedTab = tab
            }
            if let code = router.selectedWeekday,
               let date = resolveDate(for: code) {
                selectedDate = date
            }
        }

        private func resolveDate(for weekdayCode: String) -> Date? {
            let mapping: [String: Int] = [
                "sun": 1,
                "mon": 2,
                "tue": 3,
                "wed": 4,
                "thu": 5,
                "fri": 6,
                "sat": 7
            ]
            guard let weekday = mapping[weekdayCode.lowercased()] else { return nil }
            guard let startOfWeek = calendar.date(from: calendar.dateComponents([
                .yearForWeekOfYear,
                .weekOfYear
            ], from: Date())) else {
                return nil
            }
            return calendar.date(byAdding: .day, value: weekday - 1, to: startOfWeek)
        }

        private func weekdayCode(for date: Date) -> String {
            let mapping: [Int: String] = [
                1: "sun",
                2: "mon",
                3: "tue",
                4: "wed",
                5: "thu",
                6: "fri",
                7: "sat"
            ]
            let weekday = calendar.component(.weekday, from: date)
            return mapping[weekday] ?? "mon"
        }
    #endif
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

// swiftlint:enable type_body_length
