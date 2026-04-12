import SwiftUI

struct MenuBarPanelView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.showPresetEditorAction) private var showPresetEditorAction

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Divider()
                .accessibilityHidden(true)

            Toggle(appState.isBypassed ? "Off" : "On", isOn: Binding(
                get: { !appState.isBypassed },
                set: { appState.setBypassed(!$0) }
            ))
            .toggleStyle(.switch)
            .focusable()
            .accessibilityLabel("Toggle color effect")
            .accessibilityValue(appState.isBypassed ? "Off" : "On")
            .accessibilityHint("Turns the display color effect on or off.")

            Divider()
                .accessibilityHidden(true)

            Text("PRESETS")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            presetsList
        }
        .padding(14)
        .frame(width: 280)
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack {
            Text("ColorLayer")
                .font(.headline)
            Spacer()
            Button {
                showPresetEditorAction()
                dismiss()
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.borderless)
            .help("Editar presets")
            .focusable()
            .accessibilityLabel("Open preset editor")
            .accessibilityHint("Opens the preset editor window.")
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
                    .accessibilityHidden(true)
                Text(preset.name)
                    .foregroundStyle(preset.isLocked ? Color.secondary : Color.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable()
        .accessibilityLabel("Preset \(preset.name)")
        .accessibilityValue(presetAccessibilityValue(isActive: isActive, isLocked: preset.isLocked))
        .accessibilityHint("Activates this preset.")
    }

    private func presetAccessibilityValue(isActive: Bool, isLocked: Bool) -> String {
        switch (isActive, isLocked) {
        case (true, true):
            return "Selected, locked"
        case (true, false):
            return "Selected"
        case (false, true):
            return "Locked"
        case (false, false):
            return "Not selected"
        }
    }
}

private struct ShowPresetEditorActionKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable () -> Void = {}
}

extension EnvironmentValues {
    var showPresetEditorAction: @MainActor @Sendable () -> Void {
        get { self[ShowPresetEditorActionKey.self] }
        set { self[ShowPresetEditorActionKey.self] = newValue }
    }
}
