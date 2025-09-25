// 例: Model/Domain.swift
import Foundation

struct Task: Identifiable, Codable, Equatable {
  var id: UUID
  var title: String
  var due: Date?
  var note: String?
  var tags: [String] = []
}

// 例: 永続層の安全ラッパ
enum Store {
  static let url: URL = {
    let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    return dir.appendingPathComponent("tasks.json")
  }()

  static func load() -> [Task] {
    guard let data = try? Data(contentsOf: url) else {
      return Seed.defaultTasks   // ← 失敗してもデフォルト
    }
    do {
      return try JSONDecoder().decode([Task].self, from: data)
    } catch {
      print("⚠️ decode failed: \(error)")
      return Seed.defaultTasks
    }
  }

  static func save(_ tasks: [Task]) {
    do {
      let data = try JSONEncoder().encode(tasks)
      try data.write(to: url, options: .atomic)
    } catch {
      print("⚠️ save failed: \(error)")
    }
  }
}

// 例: Model/Seed.swift
enum Seed {
  static let defaultTasks: [Task] = [
    .init(id: UUID(), title: "Write spec", due: .now.addingTimeInterval(86400)),
    .init(id: UUID(), title: "Implement ListUI"),
  ]
}
