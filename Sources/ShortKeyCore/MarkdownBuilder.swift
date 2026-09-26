import Foundation

/// 生成 Markdown 格式的快捷键文档（纯逻辑，可单测）
public enum MarkdownBuilder {
    public static func build(
        appName: String,
        items: [ShortcutItem],
        favorites: Set<String> = [],
        date: Date = Date()
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let stamp = formatter.string(from: date)

        var lines: [String] = []
        lines.append("# \(appName) 快捷键")
        lines.append("")
        lines.append("> 导出时间：\(stamp) · 共 \(items.count) 个快捷键")

        // 按菜单分组，保持原始顺序
        var order: [String] = []
        var byGroup: [String: [ShortcutItem]] = [:]
        for item in items {
            if byGroup[item.group] == nil { order.append(item.group) }
            byGroup[item.group, default: []].append(item)
        }

        for group in order {
            lines.append("")
            lines.append("## \(group)")
            lines.append("")
            lines.append("| 快捷键 | 功能 |")
            lines.append("| --- | --- |")
            for item in byGroup[group] ?? [] {
                let star = favorites.contains(item.id) ? "★ " : ""
                let keys = item.modifiers.symbols + item.key
                let title = item.title.replacingOccurrences(of: "|", with: "\\|")
                lines.append("| \(star)\(keys) | \(title) |")
            }
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }
}
