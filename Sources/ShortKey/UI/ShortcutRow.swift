import SwiftUI
import ShortKeyCore

/// 单行：悬停操作（收藏/隐藏）+ 标题（搜索高亮）+ KeyCue 式蓝色键名
struct ShortcutRow: View {
    let item: ShortcutItem
    let isFavorite: Bool
    let isHidden: Bool
    let match: FuzzyMatch?
    var onToggleFavorite: () -> Void
    var onToggleHidden: () -> Void
    var onExecute: () -> Void
    /// ↑↓ 搜索导航选中态
    var isSelected: Bool = false
    /// 行字号（设置可调）
    var fontSize: Double = 13

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Group {
                starButton
                eyeButton
            }
            .opacity(isHovering || isFavorite || isHidden ? 1 : 0)
            .frame(width: 32, alignment: .leading)

            titleText
                .font(.system(size: fontSize))
                .lineLimit(1)
                .truncationMode(.middle)
                .opacity(item.isEnabled && !isHidden ? 1 : 0.4)
                .strikethrough(isHidden)

            Spacer(minLength: 10)

            Text(item.modifiers.symbols + item.key)
                .font(.system(size: fontSize - 0.5, weight: .medium, design: .rounded))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
                .opacity(item.isEnabled && !isHidden ? 1 : 0.5)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(
                    isSelected
                        ? AnyShapeStyle(Color.accentColor.opacity(0.18))
                        : (isHovering ? AnyShapeStyle(Color.primary.opacity(0.06)) : AnyShapeStyle(Color.clear))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onExecute() }
        .onHover { isHovering = $0 }
    }

    private var starButton: some View {
        Button(action: onToggleFavorite) {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: 10))
                .foregroundStyle(isFavorite ? AnyShapeStyle(Color.yellow) : AnyShapeStyle(Color.secondary))
        }
        .buttonStyle(.plain)
        .help(isFavorite ? "取消收藏" : "收藏")
    }

    private var eyeButton: some View {
        Button(action: onToggleHidden) {
            Image(systemName: isHidden ? "eye.slash.fill" : "eye.slash")
                .font(.system(size: 10))
                .foregroundStyle(isHidden ? AnyShapeStyle(Color.orange) : AnyShapeStyle(Color.orange))
        }
        .foregroundStyle(isHidden ? AnyShapeStyle(Color.orange) : AnyShapeStyle(Color.secondary))
        .buttonStyle(.plain)
        .help(isHidden ? "取消隐藏" : "隐藏此快捷键")
    }

    private var titleText: some View {
        Group {
            if let highlighted = highlightedTitle {
                Text(highlighted)
            } else {
                Text(item.title)
            }
        }
    }

    /// 搜索命中高亮（大小写折叠后长度一致时才逐字标色，避免索引错位）
    private var highlightedTitle: AttributedString? {
        guard let match, !match.indices.isEmpty,
              item.title.lowercased().count == item.title.count else { return nil }
        var result = AttributedString()
        let indices = Set(match.indices)
        for (index, character) in item.title.enumerated() {
            var part = AttributedString(String(character))
            if indices.contains(index) {
                part.backgroundColor = Color.accentColor.opacity(0.22)
            }
            result += part
        }
        return result
    }
}
