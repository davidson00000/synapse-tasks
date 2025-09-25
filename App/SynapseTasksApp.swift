import SwiftUI

@main
struct SynapseTasksApp: App {
    @StateObject private var store: TaskStore
    private let launchSettings: LaunchSettings

    init() {
        let environment = ProcessInfo.processInfo.environment
        _store = StateObject(wrappedValue: TaskStore(environment: environment))
        launchSettings = LaunchSettings(environment: environment)
    }

    var body: some Scene {
        WindowGroup {
            TaskListView(
                initialTab: launchSettings.initialTab,
                initialDate: launchSettings.initialDate,
                calendar: launchSettings.calendar
            )
            .environmentObject(store)
        }
    }
}

private struct LaunchSettings {
    let initialTab: TaskListView.Tab
    let initialDate: Date
    let calendar: Calendar

    init(environment: [String: String]) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.firstWeekday = 2
        self.calendar = calendar

        if let rawValue = environment["TASKS_SCREENSHOT_TAB"]?.lowercased(),
           let tab = TaskListView.Tab(rawValue: rawValue) {
            initialTab = tab
        } else {
            initialTab = .list
        }

        let today = calendar.startOfDay(for: Date())
        if let weekdayValue = environment["TASKS_SELECTED_WEEKDAY"],
           let weekday = Int(weekdayValue),
           (1 ... 7).contains(weekday) {
            initialDate = LaunchSettings.resolveDate(for: weekday, calendar: calendar, reference: today)
        } else {
            initialDate = today
        }
    }

    private static func resolveDate(for weekday: Int, calendar: Calendar, reference: Date) -> Date {
        guard let startOfWeek = calendar.date(from: calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: reference
        )) else {
            return reference
        }
        return calendar.date(byAdding: .day, value: weekday - 1, to: startOfWeek) ?? reference
    }
}
