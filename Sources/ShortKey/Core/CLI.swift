import AppKit
import Foundation

/// CLI 参数：
///   ShortKey --show              显示当前前台应用的快捷键浮层
///   ShortKey --export [路径]      导出当前前台应用快捷键 Markdown（缺省写到桌面）
///   ShortKey --quit              退出常驻实例
///   ShortKey --help
/// 已有常驻实例时经分布式通知转发，新进程随即退出。
enum CLI {
    enum Action {
        case show
        case quit
        case export(path: String?)
    }

    static let bundleID = "app.shortkey.ShortKey"
    static let notificationName = Notification.Name("app.shortkey.cli")

    static func parseArguments() -> Action? {
        let arguments = CommandLine.arguments
        if arguments.contains("--show") { return .show }
        if arguments.contains("--quit") { return .quit }
        if let index = arguments.firstIndex(of: "--export") {
            let path = index + 1 < arguments.count && !arguments[index + 1].hasPrefix("-") ? arguments[index + 1] : nil
            return .export(path: path)
        }
        return nil
    }

    static func usage() -> String {
        """
        ShortKey — 类 KeyCue 快捷键提示工具
        用法:
          ShortKey --show            显示前台应用快捷键浮层
          ShortKey --export [路径]    导出前台应用快捷键 Markdown
          ShortKey --quit            退出常驻实例
          ShortKey --help            显示本帮助
        """
    }

    /// 已有常驻实例则转发并退出；返回是否已处理
    @discardableResult
    static func forwardIfResident(_ action: Action) -> Bool {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        guard !running.isEmpty else { return false }

        var userInfo: [String: Any] = [:]
        switch action {
        case .show: userInfo["action"] = "show"
        case .quit: userInfo["action"] = "quit"
        case .export(let path): userInfo = ["action": "export", "path": path ?? ""]
        }
        DistributedNotificationCenter.default().postNotificationName(
            notificationName, object: nil, userInfo: userInfo, deliverImmediately: true
        )
        return true
    }
}
