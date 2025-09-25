import SwiftUI
import OSLog

@main
struct SynapseTasksApp: App {
    @StateObject private var store = TaskStore()
    init() {
        print("🔥 App init")
        Logger(subsystem: "com.kousuke.synapsetasks", category: "lifecycle").info("App init")
    }
    var body: some Scene {
        WindowGroup {
            TaskListView()
                .environmentObject(store)
                .onAppear {
                    print("👀 TaskListView root onAppear")
                    Logger(subsystem: "com.kousuke.synapsetasks", category: "ui").info("TaskListView appeared")
                }
        }
    }
}

