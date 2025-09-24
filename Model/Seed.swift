import CoreData
import Foundation

enum Seed {
    static func bootstrapIfNeeded(using context: NSManagedObjectContext) {
        context.perform {
            let request: NSFetchRequest<Task> = Task.fetchRequest()
            request.fetchLimit = 1

            let existingCount = (try? context.count(for: request)) ?? 0
            guard existingCount == 0 else { return }

            let categories = createCategories(in: context)
            let tags = createTags(in: context)
            let tasks = createTasks(count: 30, categories: categories, tags: tags, in: context)
            createConnections(from: tasks, in: context)

            do {
                try context.save()
            } catch {
                context.rollback()
                assertionFailure("Failed to seed data: \(error)")
            }
        }
    }

    // MARK: Category & Tags

    private static func createCategories(in context: NSManagedObjectContext) -> [Category] {
        ["Planning", "Build", "Review", "Launch", "Retro"].map { name in
            let category = Category(context: context)
            category.name = name
            return category
        }
    }

    private static func createTags(in context: NSManagedObjectContext) -> [Tag] {
        [
            "iOS",
            "UX",
            "Backend",
            "Docs",
            "Metrics",
            "Automation",
            "Meeting",
            "Bugfix"
        ].map { name in
            let tag = Tag(context: context)
            tag.name = name
            return tag
        }
    }

    // MARK: Tasks

    private static func createTasks(
        count: Int,
        categories: [Category],
        tags: [Tag],
        in context: NSManagedObjectContext
    ) -> [Task] {
        var tasks: [Task] = []
        tasks.reserveCapacity(count)

        let baseDate = Date()
        let calendar = Calendar.current

        for index in 0..<count {
            let task = Task(context: context)
            task.title = "Sample Task #\(index + 1)"
            task.detail = "This is a placeholder detail for task number \(index + 1)."
            task.priority = Int16((index % 5) + 1)

            switch index % 3 {
            case 0:
                task.taskStatus = .todo
            case 1:
                task.taskStatus = .doing
            default:
                task.taskStatus = .done
            }

            if index % 2 == 0 {
                task.dueDate = calendar.date(byAdding: .day, value: index - 10, to: baseDate)
            }

            task.category = categories[index % categories.count]

            let tagSet = task.mutableSetValue(forKey: "tags")
            tags.shuffled().prefix(2).forEach { tagSet.add($0) }

            let layout = NodeLayout(context: context)
            layout.x = Double(index % 6) * 160.0
            layout.y = Double(index / 6) * 140.0
            layout.locked = index % 7 == 0
            task.node = layout

            tasks.append(task)
        }

        return tasks
    }

    // MARK: Connections

    private static func createConnections(from tasks: [Task], in context: NSManagedObjectContext) {
        guard tasks.count > 1 else { return }

        for index in stride(from: 0, to: tasks.count - 1, by: 3) {
            let fromTask = tasks[index]
            let toTask = tasks[index + 1]

            let connection = Connection(context: context)
            connection.connectionKind = connectionKind(for: index)
            connection.fromTask = fromTask
            connection.toTask = toTask
        }

        if let first = tasks.first, let last = tasks.last {
            let wrapConnection = Connection(context: context)
            wrapConnection.connectionKind = .related
            wrapConnection.fromTask = last
            wrapConnection.toTask = first
        }
    }

    private static func connectionKind(for index: Int) -> ConnectionKind {
        switch index % 3 {
        case 0: return .related
        case 1: return .dependsOn
        default: return .blockedBy
        }
    }
}
