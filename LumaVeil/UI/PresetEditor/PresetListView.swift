import SwiftUI
import UniformTypeIdentifiers

struct PresetListView: View {
    private static let reorderUTTypes = [UTType.plainText.identifier]

    @ObservedObject var appState: AppState

    @State private var renamingPresetID: UUID?
    @State private var draftName = ""
    @State private var isReordering = false
    @State private var draggedPresetID: UUID?
    @State private var dropTarget: PresetDropTarget?
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
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                }

                if let lockedPreset = appState.lockedPreset {
                    presetRow(for: lockedPreset)
                        .tag(Optional(lockedPreset.id))
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                }
            }
            .listStyle(.inset)
            .accessibilityLabel("Preset list")
            .accessibilityHint(isReordering ? "Drag presets using the handle to reorder them." : "Use arrow keys to browse presets and Space to activate the selected preset.")

            Divider()
                .accessibilityHidden(true)

            HStack(spacing: 10) {
                Button {
                    let newPresetID = appState.createPreset()
                    beginRenaming(presetID: newPresetID)
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(isReordering)
                .help("Crear preset")
                .focusable()
                .accessibilityLabel("Create preset")
                .accessibilityHint("Creates a new editable preset.")

                Button {
                    guard let activePresetID = appState.activePresetID else {
                        return
                    }

                    deletePreset(id: activePresetID)
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(isReordering || !appState.canDeleteActivePreset)
                .help("Eliminar preset")
                .focusable()
                .accessibilityLabel("Delete preset")
                .accessibilityHint("Deletes the selected preset.")

                Button(isReordering ? "Hecho" : "Ordenar") {
                    toggleReordering()
                }
                .focusable()
                .accessibilityLabel(isReordering ? "Finish reordering presets" : "Reorder presets")

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
        let isActive = appState.activePresetID == preset.id
        let isDragged = draggedPresetID == preset.id && dropTarget != nil

        Group {
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
                HStack(spacing: 8) {
                    reorderHandle(for: preset)

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
                }
                .contextMenu {
                    Button("Renombrar") {
                        beginRenaming(presetID: preset.id)
                    }
                    .disabled(preset.isLocked || isReordering)
                    .accessibilityLabel("Rename preset")

                    Button("Duplicar") {
                        if let duplicatedPresetID = appState.duplicatePreset(id: preset.id) {
                            beginRenaming(presetID: duplicatedPresetID)
                        }
                    }
                    .disabled(preset.isLocked || isReordering)
                    .accessibilityLabel("Duplicate preset")

                    Button("Eliminar") {
                        deletePreset(id: preset.id)
                    }
                    .disabled(isReordering || !appState.canDeletePreset(id: preset.id))
                    .accessibilityLabel("Delete preset")
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(isDragged ? 0.3 : 1)
        .overlay(alignment: .top) {
            if dropTarget == PresetDropTarget(presetID: preset.id, position: .before) {
                insertionIndicator
            }
        }
        .overlay(alignment: .bottom) {
            if dropTarget == PresetDropTarget(presetID: preset.id, position: .after) {
                insertionIndicator
            }
        }
        .onDrop(
            of: Self.reorderUTTypes,
            delegate: PresetRowDropDelegate(
                presetID: preset.id,
                isEnabled: isReordering && !preset.isLocked,
                appState: appState,
                draggedPresetID: $draggedPresetID,
                dropTarget: $dropTarget
            )
        )
    }

    @ViewBuilder
    private func reorderHandle(for preset: Preset) -> some View {
        if isReordering, !preset.isLocked {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .frame(width: 16)
                .help("Reordenar preset")
                .onDrag {
                    draggedPresetID = preset.id
                    dropTarget = nil
                    return NSItemProvider(object: preset.id.uuidString as NSString)
                }
        } else {
            EmptyView()
        }
    }

    private var insertionIndicator: some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(height: 2)
            .padding(.leading, isReordering ? 22 : 0)
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
        resetRenamingState()
    }

    private func deletePreset(id: UUID) {
        appState.deletePreset(id: id)

        guard renamingPresetID == id else {
            return
        }

        resetRenamingState()
    }

    private func toggleReordering() {
        isReordering.toggle()
        clearDragState()

        if isReordering {
            resetRenamingState()
        }
    }

    private func resetRenamingState() {
        renamingPresetID = nil
        draftName = ""
        focusedPresetID = nil
    }

    private func clearDragState() {
        draggedPresetID = nil
        dropTarget = nil
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

private struct PresetDropTarget: Equatable {
    let presetID: UUID
    let position: InsertionPosition
}

private enum InsertionPosition {
    case before
    case after
}

private struct PresetRowDropDelegate: DropDelegate {
    let presetID: UUID
    let isEnabled: Bool
    let appState: AppState
    @Binding var draggedPresetID: UUID?
    @Binding var dropTarget: PresetDropTarget?

    func validateDrop(info: DropInfo) -> Bool {
        isEnabled && draggedPresetID != nil
    }

    func dropEntered(info: DropInfo) {
        updateDropTarget(with: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateDropTarget(with: info)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        guard dropTarget?.presetID == presetID else {
            return
        }

        dropTarget = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard
            isEnabled,
            let draggedPresetID,
            let sourceIndex = appState.editablePresets.firstIndex(where: { $0.id == draggedPresetID }),
            let targetIndex = appState.editablePresets.firstIndex(where: { $0.id == presetID })
        else {
            clearDragState()
            return false
        }

        let position = insertionPosition(for: info)
        let destination = targetIndex + (position == .after ? 1 : 0)

        guard sourceIndex != targetIndex || position == .after else {
            clearDragState()
            return false
        }

        appState.movePresets(from: IndexSet(integer: sourceIndex), to: destination)
        clearDragState()
        return true
    }

    private func updateDropTarget(with info: DropInfo) {
        guard isEnabled, draggedPresetID != presetID else {
            return
        }

        dropTarget = PresetDropTarget(presetID: presetID, position: insertionPosition(for: info))
    }

    private func insertionPosition(for info: DropInfo) -> InsertionPosition {
        info.location.y > 16 ? .after : .before
    }

    private func clearDragState() {
        draggedPresetID = nil
        dropTarget = nil
    }
}
