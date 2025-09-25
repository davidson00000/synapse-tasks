import SwiftUI

@main
struct SynapseTasksApp: App {
    @StateObject private var store = TaskStore()
    #if DEBUG
        @StateObject private var router = AppRouter()
    #endif

    init() {
        #if DEBUG
            if let tab = CIUICapture.initialTab {
                router.selectedTab = tab
            }
            if let wd = CIUICapture.selectedWeekday {
                router.selectedWeekday = wd
            }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            TaskListView()
                .environmentObject(store)
            #if DEBUG
                .environmentObject(router)
            #endif
        }
    }
}
