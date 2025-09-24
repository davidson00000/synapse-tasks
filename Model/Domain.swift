import CoreData
import SwiftUI

// 状態/種別のドメイン表現（データベースには String として保存）
enum TaskStatus: String, CaseIterable {
    case todo, doing, done
    var displayName: String {
        switch self { case .todo: "To Do"; case .doing: "Doing"; case .done: "Done" }
    }

    var icon: String {
        switch self { case .todo: "square"; case .doing: "clock"; case .done: "checkmark.circle" }
    }

    var color: Color {
        switch self { case .todo: .blue; case .doing: .orange; case .done: .green }
    }
}

enum ConnectionKind: String, CaseIterable {
    case related, dependsOn, blockedBy
}

// Core Data の自動生成クラス（TaskEntity 等）への拡張だけを書く
extension TaskEntity {
    var taskStatus: TaskStatus {
        get { TaskStatus(rawValue: status ?? "todo") ?? .todo }
        set { status = newValue.rawValue }
    }

    var safeTitle: String { title ?? "" }

    // 初期化時に安全な初期値を入れるユーティリティ
    func initializeIfNeeded() {
        if id == nil { id = UUID() }
        if createdAt == nil { createdAt = Date() }
        if updatedAt == nil { updatedAt = Date() }
        if status == nil { status = TaskStatus.todo.rawValue }
        if priority == 0 { priority = 3 }
    }
}
