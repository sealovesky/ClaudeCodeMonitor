import SwiftUI

struct SettingsView: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.dismiss) private var dismiss

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
        .frame(width: 300, height: 300)
    }
}
