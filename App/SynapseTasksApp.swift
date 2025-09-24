import CoreData
import SwiftUI

@main
struct SynapseTasksApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            TaskListView() // ← とりあえず一覧ビュー（後で差し替えOK）
                .environment(\.managedObjectContext,
                             persistenceController.container.viewContext)
        }
    }
}
