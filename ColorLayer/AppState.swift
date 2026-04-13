import Combine
import Foundation
import OSLog
import ServiceManagement

enum AppLog {
    static let subsystem = "com.diegofernandezmunoz.ColorLayer"
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let display = Logger(subsystem: subsystem, category: "display")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let overlay = Logger(subsystem: subsystem, category: "overlay")
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState(store: PresetStore())

    @Published var presets: [Preset]
    @Published var activePresetID: UUID?
    @Published var isBypassed: Bool
    @Published var liveParameters: FilterParameters
    @Published private(set) var launchAtLoginEnabled: Bool

    var hasUnsavedChanges: Bool {
        guard let activePreset else {
            return false
        }

        return activePreset.parameters != liveParameters
    }

    var activePreset: Preset? {
        guard let activePresetID else {
            return nil
        }

        return presets.first(where: { $0.id == activePresetID })
    }

    var editablePresets: [Preset] {
        presets.filter { !$0.isLocked }
    }

    var lockedPreset: Preset? {
        presets.last(where: \.isLocked)
    }

    var menuBarSymbolName: String {
        if isBypassed {
            return "circle.bottomrighthalf.pattern.checkered"
        }

        return "lightspectrum.horizontal"
    }

    var isActivePresetLocked: Bool {
        activePreset?.isLocked ?? false
    }

    var canDeleteActivePreset: Bool {
        guard let activePreset else {
            return false
        }

        return !activePreset.isLocked && editablePresets.count > 1
    }

    var canDuplicateActivePreset: Bool {
        guard let activePreset else {
            return false
        }

        return !activePreset.isLocked
    }

    private let store: any PresetStoring
    private let userDefaults: UserDefaults
    private let launchAtLoginController: any LaunchAtLoginControlling

    init(
        store: any PresetStoring,
        userDefaults: UserDefaults = .standard,
        launchAtLoginController: any LaunchAtLoginControlling = MainAppLaunchAtLoginController()
    ) {
        self.store = store
        self.userDefaults = userDefaults
        self.launchAtLoginController = launchAtLoginController

        let loadedPresets = FactoryPresets.repairedLibrary(from: store.loadPresets())
        let session = store.loadSession()

        presets = loadedPresets
        isBypassed = session.isBypassed

        if let activePresetID = session.activePresetID, let preset = loadedPresets.first(where: { $0.id == activePresetID }) {
            self.activePresetID = activePresetID
            liveParameters = preset.parameters
        } else {
            activePresetID = nil
            liveParameters = .neutral
        }

        launchAtLoginEnabled = launchAtLoginController.status == .enabled
        persistLaunchAtLoginPreference(launchAtLoginEnabled)

        if activePresetID != session.activePresetID {
            persistSession()
        }
    }

    func selectPreset(_ id: UUID?) {
        guard let id else {
            activePresetID = nil
            liveParameters = .neutral
            persistSession()
            return
        }

        guard let preset = presets.first(where: { $0.id == id }) else {
            activePresetID = nil
            liveParameters = .neutral
            persistSession()
            return
        }

        activePresetID = preset.id
        liveParameters = preset.parameters
        persistSession()
    }

    func setBypassed(_ bypassed: Bool) {
        if isBypassed != bypassed {
            AppLog.lifecycle.info("Effect \(bypassed ? "disabled" : "enabled", privacy: .public) via bypass toggle.")
        }

        isBypassed = bypassed
        persistSession()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard launchAtLoginEnabled != enabled else {
            refreshLaunchAtLoginStatus()
            return
        }

        do {
            if enabled {
                try launchAtLoginController.register()
            } else {
                try launchAtLoginController.unregister()
            }
        } catch {
            AppLog.lifecycle.error("Failed to update launch at login state: \(error.localizedDescription, privacy: .public)")
        }

        refreshLaunchAtLoginStatus()
    }

    func refreshLaunchAtLoginStatus() {
        let isEnabled = launchAtLoginController.status == .enabled
        launchAtLoginEnabled = isEnabled
        persistLaunchAtLoginPreference(isEnabled)
    }

    @discardableResult
    func createPreset() -> UUID {
        let newPreset = Preset(
            id: UUID(),
            name: "Sin nombre",
            createdAt: Date(),
            parameters: .neutral,
            isLocked: false
        )

        insertEditablePreset(newPreset)
        selectPreset(newPreset.id)
        persistPresets()
        return newPreset.id
    }

    @discardableResult
    func duplicatePreset(id: UUID? = nil) -> UUID? {
        let sourceID = id ?? activePresetID

        guard
            let sourceID,
            let sourcePreset = presets.first(where: { $0.id == sourceID }),
            !sourcePreset.isLocked
        else {
            return nil
        }

        let duplicatedPreset = Preset(
            id: UUID(),
            name: "Copia de \(sourcePreset.name)",
            createdAt: Date(),
            parameters: sourcePreset.parameters,
            isLocked: false
        )

        insertEditablePreset(duplicatedPreset, after: sourcePreset.id)
        selectPreset(duplicatedPreset.id)
        persistPresets()
        return duplicatedPreset.id
    }

    func renamePreset(id: UUID, to newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            !trimmedName.isEmpty,
            let index = presets.firstIndex(where: { $0.id == id }),
            !presets[index].isLocked
        else {
            return
        }

        presets[index].name = trimmedName
        persistPresets()
    }

    func deletePreset(id: UUID) {
        guard
            let index = presets.firstIndex(where: { $0.id == id }),
            !presets[index].isLocked
        else {
            return
        }

        presets.remove(at: index)

        if activePresetID == id {
            activePresetID = nil
            liveParameters = .neutral
        }

        normalizePresets()
        persistPresets()
        persistSession()
    }

    func movePresets(from source: IndexSet, to destination: Int) {
        guard !source.isEmpty else {
            return
        }

        var reorderedPresets = editablePresets
        reorderedPresets.move(fromOffsets: source, toOffset: destination)

        let lockedPresets = presets.filter(\.isLocked)
        presets = reorderedPresets + lockedPresets
        normalizePresets()
        persistPresets()
    }

    func saveActivePresetChanges() {
        guard
            let activePresetID,
            let index = presets.firstIndex(where: { $0.id == activePresetID }),
            !presets[index].isLocked
        else {
            return
        }

        presets[index].parameters = liveParameters
        persistPresets()
    }

    func discardActivePresetChanges() {
        guard let activePreset else {
            liveParameters = .neutral
            return
        }

        liveParameters = activePreset.parameters
    }

    private func insertEditablePreset(_ preset: Preset, after id: UUID? = nil) {
        let insertionIndex: Int

        if
            let id,
            let sourceIndex = presets.firstIndex(where: { $0.id == id && !$0.isLocked })
        {
            insertionIndex = sourceIndex + 1
        } else if let lockedIndex = presets.firstIndex(where: \.isLocked) {
            insertionIndex = lockedIndex
        } else {
            insertionIndex = presets.endIndex
        }

        presets.insert(preset, at: insertionIndex)
        normalizePresets()
    }

    private func normalizePresets() {
        presets = FactoryPresets.repairedLibrary(from: presets)
    }

    private func persistPresets() {
        store.savePresets(presets)
    }

    private func persistSession() {
        store.saveSession(activePresetID: activePresetID, isBypassed: isBypassed)
    }

    private func persistLaunchAtLoginPreference(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: AppDefaultsKey.launchAtLogin)
    }
}

protocol LaunchAtLoginControlling {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

struct MainAppLaunchAtLoginController: LaunchAtLoginControlling {
    var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

private extension Array {
    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let elements = source.map { self[$0] }
        let adjustedDestination = destination - source.filter { $0 < destination }.count

        for index in source.sorted(by: >) {
            remove(at: index)
        }

        insert(contentsOf: elements, at: adjustedDestination)
    }
}
