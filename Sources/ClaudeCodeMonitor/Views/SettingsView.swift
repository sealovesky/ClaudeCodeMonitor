import SwiftUI

struct SettingsView: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @AppStorage("showInMenuBar") private var showInMenuBar: Bool = true
    /// inline 二次确认（不能用 .confirmationDialog —— 它抢焦点会让 popover 闭合）
    @State private var hidePending: Bool = false

    var body: some View {
        @Bindable var store = store

        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)

            // Launch at Login
            HStack {
                Toggle("Launch at Login", isOn: Binding(
                    get: { LaunchAtLogin.isEnabled },
                    set: { _ in LaunchAtLogin.toggle() }
                ))
            }

            // Show in Menu Bar
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Show icon in menu bar", isOn: Binding(
                    // get 用 effective state — 含 reopen 临时强显，跟用户实际看到的一致
                    get: { (showInMenuBar || store.temporaryMenuBarShow) && !hidePending },
                    set: { newValue in
                        if !newValue {
                            hidePending = true
                        } else {
                            showInMenuBar = true
                            store.temporaryMenuBarShow = false
                            hidePending = false
                        }
                    }
                ))
                if hidePending {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hide icon? You'll need to launch the app from Finder / Spotlight again to bring it back.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            Button("Hide", role: .destructive) {
                                showInMenuBar = false
                                // 同时清 reopen 临时强显 — menuBarBinding 是 OR 关系，
                                // 不清掉 60s 内 hide 无效
                                store.temporaryMenuBarShow = false
                                hidePending = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    NSApp.keyWindow?.close()
                                }
                            }
                            Button("Cancel") {
                                hidePending = false
                            }
                        }
                    }
                    .padding(8)
                    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                } else if !showInMenuBar {
                    Text("Icon is hidden. Re-launch the app from Finder / Spotlight to access Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Thresholds
            Text("Menu Bar Color Thresholds")
                .font(.subheadline.weight(.medium))

            HStack {
                Circle().fill(.green).frame(width: 10, height: 10)
                Text("Green < ")
                    .font(.caption)
                TextField("", value: $store.greenThreshold, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Text("msgs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Circle().fill(.yellow).frame(width: 10, height: 10)
                Text("Yellow < ")
                    .font(.caption)
                TextField("", value: $store.yellowThreshold, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Text("msgs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Circle().fill(.red).frame(width: 10, height: 10)
                Text("Red >=")
                    .font(.caption)
                Text("\(store.yellowThreshold) msgs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 320, height: 380)
    }
}
