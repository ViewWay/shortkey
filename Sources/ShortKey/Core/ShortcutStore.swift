import Foundation

/// 收藏 / 隐藏状态持久化（按应用 bundleID 分组），JSON 存于 Application Support。
/// 文件结构：{ "<bundleID>": { "favorites": ["<条目id>"], "hidden": ["<条目id>"] } }
@MainActor
final class ShortcutStore {
    struct AppState: Codable {
        var favorites: Set<String> = []
        var hidden: Set<String> = []
    }

    private var states: [String: AppState] = [:]
    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ShortKey", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("state.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: AppState].self, from: data) {
            states = decoded
        }
    }

    func state(for bundleID: String) -> AppState {
        states[bundleID] ?? AppState()
    }

    func toggleFavorite(_ id: String, bundleID: String) {
        var state = state(for: bundleID)
        if state.favorites.contains(id) {
            state.favorites.remove(id)
        } else {
            state.favorites.insert(id)
        }
        states[bundleID] = state
        save()
    }

    /// M2 接入 UI 开关：隐藏「已知」快捷键
    func toggleHidden(_ id: String, bundleID: String) {
        var state = state(for: bundleID)
        if state.hidden.contains(id) {
            state.hidden.remove(id)
        } else {
            state.hidden.insert(id)
        }
        states[bundleID] = state
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(states) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
