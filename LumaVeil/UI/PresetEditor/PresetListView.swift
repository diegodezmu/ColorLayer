import SwiftUI

struct PresetListView: View {
    @ObservedObject var appState: AppState

    @State private var renamingPresetID: UUID?
    @State private var draftName = ""
    @FocusState private var focusedPresetID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Presets")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .accessibilityAddTraits(.isHeader)

            List(selection: Binding(
                get: { appState.activePresetID },
                set: { appState.selectPreset($0) }
            )) {
                ForEach(appState.editablePresets) { preset in
                    presetRow(for: preset)
                        .tag(Optional(preset.id))
                }
                .onMove(perform: appState.movePresets)

                if let lockedPreset = appState.lockedPreset {
                    presetRow(for: lockedPreset)
                        .tag(Optional(lockedPreset.id))
                }
            }
            .listStyle(.inset)
            .accessibilityLabel("Preset list")
            .accessibilityHint("Use arrow keys to browse presets and Space to activate the selected preset.")

            Divider()
                .accessibilityHidden(true)

            HStack(spacing: 10) {
                Button {
                    let newPresetID = appState.createPreset()
                    beginRenaming(presetID: newPresetID)
                } label: {
                    Image(systemName: "plus")
                }
                .help("Crear preset")
                .focusable()
                .accessibilityLabel("Create preset")
                .accessibilityHint("Creates a new editable preset.")

                Button {
                    guard let activePresetID = appState.activePresetID else {
                        return
                    }

                    appState.deletePreset(id: activePresetID)
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(!appState.canDeleteActivePreset)
                .help("Eliminar preset")
                .focusable()
                .accessibilityLabel("Delete preset")
                .accessibilityHint("Deletes the selected preset.")

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 16)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
        }
    }

    @ViewBuilder
    private func presetRow(for preset: Preset) -> some View {
        if renamingPresetID == preset.id, !preset.isLocked {
            TextField("Nombre", text: $draftName, onCommit: commitRename)
                .textFieldStyle(.plain)
                .focused($focusedPresetID, equals: preset.id)
                .accessibilityLabel("Preset name")
                .accessibilityValue(draftName)
                .onAppear {
                    focusedPresetID = preset.id
                }
        } else {
            let isActive = appState.activePresetID == preset.id

            Button {
                appState.selectPreset(preset.id)
            } label: {
                HStack {
                    Text(preset.name)
                        .foregroundStyle(preset.isLocked ? .secondary : .primary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preset \(preset.name)")
            .accessibilityValue(presetAccessibilityValue(isActive: isActive, isLocked: preset.isLocked))
            .accessibilityHint("Selects this preset.")
            .contextMenu {
                Button("Renombrar") {
                    beginRenaming(presetID: preset.id)
                }
                .disabled(preset.isLocked)
                .accessibilityLabel("Rename preset")

                Button("Duplicar") {
                    if let duplicatedPresetID = appState.duplicatePreset(id: preset.id) {
                        beginRenaming(presetID: duplicatedPresetID)
                    }
                }
                .disabled(preset.isLocked)
                .accessibilityLabel("Duplicate preset")
            }
        }
    }

    private func beginRenaming(presetID: UUID) {
        guard let preset = appState.presets.first(where: { $0.id == presetID }), !preset.isLocked else {
            return
        }

        renamingPresetID = presetID
        draftName = preset.name
        DispatchQueue.main.async {
            focusedPresetID = presetID
        }
    }

    private func commitRename() {
        guard let renamingPresetID else {
            return
        }

        appState.renamePreset(id: renamingPresetID, to: draftName)
        self.renamingPresetID = nil
        focusedPresetID = nil
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
