#if DEBUG
import Foundation

enum CIUICapture {
    static var tab: String? {
        let env = ProcessInfo.processInfo.environment
        if let v = env["TASKS_SCREENSHOT_TAB"], !v.isEmpty { return v }
        if let arg = CommandLine.arguments.first(where: { $0.contains("TASKS_SCREENSHOT_TAB=") }) {
            return arg.split(separator: "=").last.map(String.init)
        }
        return nil
    }

    static var weekday: String? {
        let env = ProcessInfo.processInfo.environment
        if let v = env["TASKS_SELECTED_WEEKDAY"], !v.isEmpty { return v }
        if let arg = CommandLine.arguments.first(where: { $0.contains("TASKS_SELECTED_WEEKDAY=") }) {
            return arg.split(separator: "=").last.map(String.init)
        }
        return nil
    }
}
#endif
