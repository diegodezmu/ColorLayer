import SwiftUI

struct MenuBarPanelView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Divider()

            Toggle(appState.isBypassed ? "Off" : "On", isOn: Binding(
                get: { !appState.isBypassed },
                set: { appState.setBypassed(!$0) }
            ))
            .toggleStyle(.switch)

            Divider()

            Text("PRESETS")
                .font(.caption)
                .foregroundStyle(.secondary)

            presetsList
        }
        .padding(14)
        .frame(width: 280)
    }

    private var header: some View {
        HStack {
            Text("ColorLayer")
                .font(.headline)
            Spacer()
            Button {
                AppDelegate.shared?.showPresetEditor()
                dismiss()
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.borderless)
            .help("Editar presets")
        }
    }

    private var presetsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(appState.presets) { preset in
                presetButton(for: preset)
            }
        }
    }

    private func presetButton(for preset: Preset) -> some View {
        let isActive = appState.activePresetID == preset.id

        return Button {
            appState.selectPreset(preset.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                Text(preset.name)
                    .foregroundStyle(preset.isLocked ? Color.secondary : Color.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
