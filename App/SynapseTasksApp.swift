import SwiftUI

@main
struct SynapseTasksApp: App {
    private let persistenceController = PersistenceController.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TaskListView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .background else { return }
            saveContext()
        }
    }

    private func saveContext() {
        let context = persistenceController.container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to save context: \(error)")
        }
    }
}
