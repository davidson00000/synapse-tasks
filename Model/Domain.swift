import SwiftUI

enum TaskStatus: Int16, CaseIterable {
    case todo = 0
    case doing = 1
    case done = 2

    var displayName: String {
        switch self {
            case .todo:
                "To Do"
            case .doing:
                "Doing"
            case .done:
                "Done"
        }
    }

    var icon: String {
        switch self {
            case .todo:
                "checklist"
            case .doing:
                "hammer"
            case .done:
                "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
            case .todo:
                .blue
            case .doing:
                .orange
            case .done:
                .green
        }
    }
}

enum TaskPriority: Int16, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2

    var displayName: String {
        switch self {
            case .low:
                "Low"
            case .medium:
                "Medium"
            case .high:
                "High"
        }
    }
}

enum ConnectionKind: Int16, CaseIterable {
    case related = 0
    case dependsOn = 1
    case blockedBy = 2

    var displayName: String {
        switch self {
            case .related:
                "Related"
            case .dependsOn:
                "Depends On"
            case .blockedBy:
                "Blocked By"
        }
    }
}

extension TaskEntity {
    /// 既存値を壊さずに、nil/ゼロの項目だけ初期化
    func initializeIfNeeded(
        id: UUID = .init(),
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        statusRaw: Int16? = nil,
        priorityRaw: Int16? = nil
    ) {
        let now = Date()
        if self.id == nil { self.id = id }
        if self.createdAt == nil { self.createdAt = createdAt ?? now }
        if self.updatedAt == nil { self.updatedAt = updatedAt ?? now }
        if self.statusRaw == 0 { self.statusRaw = statusRaw ?? TaskStatus.todo.rawValue }
        if self.priorityRaw == 0 { self.priorityRaw = priorityRaw ?? TaskPriority.medium.rawValue }
    }
}
