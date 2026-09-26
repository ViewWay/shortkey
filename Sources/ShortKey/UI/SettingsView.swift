import ServiceManagement
import SwiftUI

/// 设置窗口：触发方式 / 阈值 / 外观 / 开机自启 / 更新检查
struct SettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        Form {
            Picker("触发方式", selection: $settings.triggerKind) {
                ForEach(SettingsStore.TriggerKind.allCases) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            HStack {
                Text("触发阈值")
                Slider(value: $settings.thresholdMs, in: 100...1000, step: 50)
                Text("\(Int(settings.thresholdMs)) ms")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .trailing)
            }
            Picker("外观", selection: $settings.appearance) {
                ForEach(SettingsStore.Appearance.allCases) { appearance in
                    Text(appearance.label).tag(appearance)
                }
            }
            Divider()
            Toggle("开机自启", isOn: Binding(
                get: { SMAppService.mainApp.status == .enabled },
                set: { enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        NSSound.beep()
                    }
                }
            ))
            Toggle("每周检查更新（通知中心提醒）", isOn: Binding(
                get: { UserDefaults.standard.object(forKey: "checkUpdates") == nil ? true : UserDefaults.standard.bool(forKey: "checkUpdates") },
                set: { UserDefaults.standard.set($0, forKey: "checkUpdates") }
            ))
            Group {
                if SMAppService.mainApp.status != .enabled {
                    Text("提示：swift run 调试模式下无法注册开机自启，请使用打包版")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
