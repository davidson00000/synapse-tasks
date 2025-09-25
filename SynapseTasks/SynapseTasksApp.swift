import SwiftUI

@main
struct SynapseTasksApp: App {
    @StateObject private var store = TaskStore()
    private let launchSettings = LaunchSettings()

    var body: some Scene {
        WindowGroup {
            TaskListView(
                initialTab: launchSettings.initialTab,
                initialWeeklyDate: launchSettings.initialWeeklyDate
            )
            .environmentObject(store)
        }
    }
}

private struct LaunchSettings {
    let initialTab: TaskListView.Tab
    let initialWeeklyDate: Date

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        if let tabValue = environment["TASKS_SCREENSHOT_TAB"]?.lowercased(),
           let tab = TaskListView.Tab(rawValue: tabValue)
        {
            initialTab = tab
        } else {
            initialTab = .list
        }

        initialWeeklyDate = LaunchSettings.resolveWeeklyDate(environment: environment)
    }

    private static func resolveWeeklyDate(environment: [String: String]) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.locale = Locale(identifier: "ja_JP")
        let today = Date()
        let startOfWeek = calendar
            .date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today

        guard let rawValue = environment["TASKS_SELECTED_WEEKDAY"],
              let weekdayIndex = Int(rawValue)
        else {
            return today
        }

        let clamped = max(1, min(7, weekdayIndex))
        return calendar.date(byAdding: .day, value: clamped - 1, to: startOfWeek) ?? today
    }
}
