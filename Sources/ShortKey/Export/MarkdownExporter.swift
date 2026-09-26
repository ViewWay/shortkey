import AppKit
import ShortKeyCore
import UniformTypeIdentifiers

enum MarkdownExporter {
    /// 弹出保存面板，将快捷键写为 Markdown 文件
    @MainActor
    static func export(appName: String, items: [ShortcutItem], favorites: Set<String>) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = "\(appName) 快捷键.md"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let document = MarkdownBuilder.build(appName: appName, items: items, favorites: favorites)
        do {
            try document.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSSound.beep()
        }
    }
}
