import SwiftUI
import ShortKeyCore

/// KeyCue 式浮层：左侧应用快捷键（3 列均衡）+ 右侧 macOS 系统热键列
struct ShortcutsView: View {
    struct Row: Identifiable {
        let item: ShortcutItem
        let match: FuzzyMatch?
        var isHidden: Bool = false
        var id: String { item.id }
    }

    struct ShortcutGroup: Identifiable {
        let name: String
        var rows: [Row]
        var id: String { name }
    }

    @ObservedObject var model: OverlayModel
    var onToggleFavorite: (String) -> Void
    var onToggleHidden: (String) -> Void
    var onExecuteItem: (ShortcutItem) -> Void
    var onClose: () -> Void
    var onExport: () -> Void

    @FocusState private var searchFocused: Bool
    /// 列数跟随设置
    private var columnCount: Int { model.columnCount }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            grid
            Divider().opacity(0.4)
            searchBar
        }
        .frame(minWidth: 980, minHeight: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.regularMaterial))
        .onAppear { searchFocused = true }
        .onChange(of: model.revision) { _, _ in
            searchFocused = true
            model.bestMatchItem = nil
        }
        .onChange(of: model.query) { _, _ in
            model.onUserActivity?()
            model.bestMatchItem = filteredRows.first?.item
        }
        .onExitCommand { onClose() }
    }

    // MARK: - 顶部：应用图标 + 名称

    private var header: some View {
        HStack(spacing: 10) {
            if let icon = model.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            }
            Text(model.appName)
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Text("\(filteredRows.count) 个应用快捷键")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button(action: onExport) {
                Image(systemName: "square.and.arrow.down")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("导出为 Markdown")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    // MARK: - 中部：应用多列 + 系统列

    private var grid: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 14) {
                appColumnsView
                Divider()
                systemColumn
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var appColumnsView: some View {
        if model.items.isEmpty {
            emptyState
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
        } else {
            HStack(alignment: .top, spacing: 14) {
                ForEach(Array(appColumns.enumerated()), id: \.offset) { _, column in
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(column) { group in
                            groupCell(group)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
    }

    private var systemColumn: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(systemGroups) { group in
                groupCell(group)
            }
        }
        .frame(width: 240, alignment: .topLeading)
    }

    private func groupCell(_ group: ShortcutGroup) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                model.toggleCollapsed(group.name)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(model.collapsedGroups.contains(group.name) ? 0 : 90))
                        .foregroundStyle(.secondary)
                    Text(group.name)
                        .font(.system(size: 12.5, weight: .bold))
                    Text("\(group.rows.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.07))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 3)

            if !model.collapsedGroups.contains(group.name) {
                ForEach(group.rows) { row in
                    ShortcutRow(
                        item: row.item,
                        isFavorite: model.favorites.contains(row.item.id),
                        isHidden: row.isHidden,
                        match: row.match,
                        onToggleFavorite: { onToggleFavorite(row.item.id) },
                        onToggleHidden: { onToggleHidden(row.item.id) },
                        onExecute: { onExecuteItem(row.item) },
                        isSelected: model.selectedItemId == row.item.id,
                        fontSize: model.rowFontSize,
                        modifierColorCoding: model.modifierColorCoding
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: model.query.isEmpty ? "keyboard" : "magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)
            Text(model.query.isEmpty
                 ? "当前应用没有可显示的快捷键"
                 : "没有匹配「\(model.query)」的结果")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 底部：搜索栏 + 图例

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索快捷键…", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($searchFocused)
            if !model.query.isEmpty {
                Button {
                    model.query = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Button {
                model.showHidden.toggle()
            } label: {
                Image(systemName: model.showHidden ? "eye" : "eye.slash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(model.showHidden ? "隐藏已知快捷键" : "显示已隐藏的快捷键")
            Spacer()
            Text("⌘=command  ⌥=option  ⇧=shift  ^ =ctrl  ␣=space  ⎋=esc  ↩=return")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    // MARK: - 数据整形

    private var filteredRows: [Row] {
        let hidden = model.hidden
        let visible = model.items.filter { model.showHidden || !hidden.contains($0.id) }
        let query = model.query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            return visible.map { Row(item: $0, match: nil, isHidden: hidden.contains($0.id)) }
        }
        var scored: [(Row, Int)] = []
        for item in visible {
            let rowHidden = hidden.contains(item.id)
            if let m = FuzzyMatcher.match(query: query, target: item.title) {
                scored.append((Row(item: item, match: m, isHidden: rowHidden), m.score))
            } else if let m = FuzzyMatcher.match(query: query, target: item.group + " " + item.path.joined(separator: " ")) {
                scored.append((Row(item: item, match: nil, isHidden: rowHidden), m.score - 15))
            }
        }
        return scored.sorted { $0.1 > $1.1 }.map(\.0)
    }

    /// 空查询：按菜单栏顺序分组（收藏组内置顶）；搜索中：合并为单一结果组
    private var groups: [ShortcutGroup] {
        let rows = filteredRows
        let query = model.query.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            return [ShortcutGroup(name: "搜索结果", rows: rows)]
        }
        var order: [String] = []
        var byGroup: [String: [Row]] = [:]
        for row in rows {
            if byGroup[row.item.group] == nil { order.append(row.item.group) }
            byGroup[row.item.group, default: []].append(row)
        }
        let favorites = model.favorites
        return order.map { name in
            var list = byGroup[name] ?? []
            let positions = Dictionary(uniqueKeysWithValues: list.enumerated().map { ($1.id, $0) })
            list.sort { a, b in
                let fa = favorites.contains(a.item.id)
                let fb = favorites.contains(b.item.id)
                if fa != fb { return fa }
                return positions[a.id]! < positions[b.id]!
            }
            return ShortcutGroup(name: name, rows: list)
        }
    }

    /// 分组按体量均衡分配到 3 列（大组先放最矮的列），列内保持菜单栏顺序
    private var appColumns: [[ShortcutGroup]] {
        let all = groups
        if all.count <= columnCount {
            return [all] + Array(repeating: [], count: columnCount - all.count)
        }
        var columns: [[ShortcutGroup]] = Array(repeating: [], count: columnCount)
        var heights = Array(repeating: 0, count: columnCount)
        for group in all.sorted(by: { $0.rows.count > $1.rows.count }) {
            let idx = heights.indices.min(by: { heights[$0] < heights[$1] }) ?? 0
            columns[idx].append(group)
            heights[idx] += group.rows.count + 2
        }
        let order = Dictionary(uniqueKeysWithValues: all.enumerated().map { ($1.name, $0) })
        return columns.map { $0.sorted { order[$0.name]! < order[$1.name]! } }
    }

    // MARK: - 系统侧列（系统热键 / 手势 / skhd / 自定义）

    private var systemGroups: [ShortcutGroup] {
        var groups: [ShortcutGroup] = [
            ShortcutGroup(name: "macOS 系统", rows: filteredSystemRows(ShortcutCatalog.systemItems)),
            ShortcutGroup(name: "触控板手势", rows: filteredSystemRows(ShortcutCatalog.gestureItems)),
        ]
        if !model.skhdItems.isEmpty {
            groups.append(ShortcutGroup(name: "skhd", rows: filteredSystemRows(model.skhdItems)))
        }
        if !model.customItems.isEmpty {
            groups.append(ShortcutGroup(name: "自定义", rows: filteredSystemRows(model.customItems)))
        }
        return groups
    }

    private func filteredSystemRows(_ items: [ShortcutItem]) -> [Row] {
        let hidden = model.hidden
        let visible = items.filter { model.showHidden || !hidden.contains($0.id) }
        let query = model.query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            return visible.map { Row(item: $0, match: nil, isHidden: hidden.contains($0.id)) }
        }
        var scored: [(Row, Int)] = []
        for item in visible {
            let rowHidden = hidden.contains(item.id)
            guard let m = FuzzyMatcher.match(query: query, target: item.title) else { continue }
            scored.append((Row(item: item, match: m, isHidden: rowHidden), m.score))
        }
        return scored.sorted { $0.1 > $1.1 }.map(\.0)
    }
}
