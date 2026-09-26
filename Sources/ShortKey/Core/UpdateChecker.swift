import Foundation
import UserNotifications

/// 每周检查一次 GitHub Releases；发现新版本时经通知中心提醒（不打扰）。
@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()
    /// 发布仓库；仓库就绪后替换为真实地址
    private let releasesURL = URL(string: "https://api.github.com/repos/ViewWay/shortkey/releases/latest")!

    func checkIfDue() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "checkUpdates") == nil {
            defaults.set(true, forKey: "checkUpdates")
        }
        guard defaults.bool(forKey: "checkUpdates") else { return }

        let last = defaults.double(forKey: "lastUpdateCheck")
        guard Date().timeIntervalSince1970 - last > 7 * 86_400 else { return }
        defaults.set(Date().timeIntervalSince1970, forKey: "lastUpdateCheck")

        Task { await check() }
    }

    private func check() async {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }

        var request = URLRequest(url: releasesURL)
        request.setValue("ShortKey/\(version)", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else { return }

        guard isNewer(tag, than: version) else { return }

        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = "ShortKey 有新版本"
        content.body = "当前 \(version)，最新 \(tag)。去 GitHub 下载新版本吧。"
        try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    /// 宽松语义化版本比较（v1.2.3 / 1.2.3 均可）
    private func isNewer(_ tag: String, than current: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            s.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                .split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
        }
        let a = parts(tag), b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let l = i < a.count ? a[i] : 0
            let r = i < b.count ? b[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
