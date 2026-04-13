import Foundation
import ServiceManagement
import Testing
@testable import ColorLayer

@MainActor
@Test
func invalidStoredSelectionResetsToNeutralState() {
    let store = InMemoryPresetStore(
        presets: FactoryPresets.seedLibrary,
        session: SessionSnapshot(activePresetID: UUID(), isBypassed: false)
    )

    let appState = AppState(store: store)

    #expect(appState.activePresetID == nil)
    #expect(appState.liveParameters == .neutral)
    #expect(store.savedSessions.last?.activePresetID == nil)
}

@MainActor
@Test
func createPresetSelectsItCopiesParametersAndPersistsLibrary() {
    let store = InMemoryPresetStore(presets: FactoryPresets.seedLibrary)
    let appState = AppState(store: store)

    let createdPresetID = appState.createPreset()

    #expect(appState.activePresetID == createdPresetID)
    #expect(appState.liveParameters == .neutral)
    #expect(appState.presets.last?.id == FactoryPresets.neutralID)
    #expect(store.savedPresets.last?.last?.id == FactoryPresets.neutralID)
}

@MainActor
@Test
func selectingNeutralKeepsItActiveAndRestoresNeutralParameters() {
    let store = InMemoryPresetStore(
        presets: FactoryPresets.seedLibrary,
        session: SessionSnapshot(activePresetID: FactoryPresets.seedLibrary[0].id, isBypassed: false)
    )
    let appState = AppState(store: store)

    appState.selectPreset(FactoryPresets.neutralID)

    #expect(appState.activePresetID == FactoryPresets.neutralID)
    #expect(appState.activePreset?.id == FactoryPresets.neutralID)
    #expect(appState.liveParameters == .neutral)
    #expect(store.savedSessions.last?.activePresetID == FactoryPresets.neutralID)
}

@MainActor
@Test
func duplicatePresetCopiesParametersAndSelectsCopy() {
    var presets = FactoryPresets.seedLibrary
    let sourcePreset = presets.removeFirst()
    presets.insert(sourcePreset, at: 0)
    let store = InMemoryPresetStore(
        presets: presets,
        session: SessionSnapshot(activePresetID: sourcePreset.id, isBypassed: false)
    )
    let appState = AppState(store: store)

    let duplicatedPresetID = appState.duplicatePreset()
    let duplicatedPreset = appState.presets.first(where: { $0.id == duplicatedPresetID })

    #expect(duplicatedPresetID != nil)
    #expect(duplicatedPreset?.parameters == sourcePreset.parameters)
    #expect(appState.activePresetID == duplicatedPresetID)
    #expect(appState.liveParameters == sourcePreset.parameters)
}

@MainActor
@Test
func renameDeleteAndReorderPersistWhileKeepingNeutralLast() {
    let store = InMemoryPresetStore(
        presets: FactoryPresets.seedLibrary,
        session: SessionSnapshot(activePresetID: FactoryPresets.seedLibrary[0].id, isBypassed: false)
    )
    let appState = AppState(store: store)
    let firstEditableID = appState.editablePresets[0].id

    appState.renamePreset(id: firstEditableID, to: "Trabajo")
    #expect(appState.presets.first?.name == "Trabajo")

    appState.movePresets(from: IndexSet(integer: 0), to: appState.editablePresets.count)
    #expect(appState.presets.last?.id == FactoryPresets.neutralID)

    appState.deletePreset(id: firstEditableID)
    #expect(appState.presets.first(where: { $0.id == firstEditableID }) == nil)
    #expect(appState.presets.last?.id == FactoryPresets.neutralID)
    #expect(store.savedPresets.last?.last?.id == FactoryPresets.neutralID)
}

@MainActor
@Test
func lockedNeutralCannotBeRenamedDuplicatedDeletedOrMoved() {
    let store = InMemoryPresetStore(
        presets: FactoryPresets.seedLibrary,
        session: SessionSnapshot(activePresetID: FactoryPresets.neutralID, isBypassed: false)
    )
    let appState = AppState(store: store)
    let originalIDs = appState.presets.map(\.id)

    appState.renamePreset(id: FactoryPresets.neutralID, to: "Otro")
    let duplicatedPresetID = appState.duplicatePreset()
    appState.deletePreset(id: FactoryPresets.neutralID)
    appState.movePresets(from: IndexSet(integer: 0), to: appState.editablePresets.count)

    #expect(duplicatedPresetID == nil)
    #expect(appState.presets.map(\.id).last == FactoryPresets.neutralID)
    #expect(appState.presets.contains(where: { $0.id == FactoryPresets.neutralID && $0.name == "Neutro" }))
    #expect(Set(appState.presets.map(\.id)) == Set(originalIDs))
}

@MainActor
@Test
func menuBarSymbolReflectsOnAndOffStates() {
    let store = InMemoryPresetStore(presets: FactoryPresets.seedLibrary)
    let appState = AppState(store: store)

    appState.activePresetID = nil
    appState.setBypassed(false)
    #expect(appState.menuBarSymbolName == "lightspectrum.horizontal")

    appState.setBypassed(true)
    #expect(appState.menuBarSymbolName == "circle.bottomrighthalf.pattern.checkered")
}

@MainActor
@Test
func hasUnsavedChangesTracksSaveAndDiscardAgainstActivePreset() {
    let sourcePreset = FactoryPresets.seedLibrary[0]
    let store = InMemoryPresetStore(
        presets: FactoryPresets.seedLibrary,
        session: SessionSnapshot(activePresetID: sourcePreset.id, isBypassed: false)
    )
    let appState = AppState(store: store)

    #expect(appState.hasUnsavedChanges == false)

    appState.liveParameters.gamma = 1.4
    #expect(appState.hasUnsavedChanges == true)

    appState.discardActivePresetChanges()
    #expect(appState.hasUnsavedChanges == false)
    #expect(appState.liveParameters == sourcePreset.parameters)

    appState.liveParameters.temperature = 0.9
    appState.saveActivePresetChanges()

    #expect(appState.hasUnsavedChanges == false)
    #expect(appState.activePreset?.parameters.temperature == 0.9)
}

@MainActor
@Test
func launchAtLoginInitialStateReflectsControllerAndPersistsIt() {
    let defaults = UserDefaults(suiteName: #function)!
    defaults.removePersistentDomain(forName: #function)
    defaults.set(false, forKey: AppDefaultsKey.launchAtLogin)

    let store = InMemoryPresetStore(presets: FactoryPresets.seedLibrary)
    let controller = TestLaunchAtLoginController(status: .enabled)
    let appState = AppState(store: store, userDefaults: defaults, launchAtLoginController: controller)

    #expect(appState.launchAtLoginEnabled)
    #expect(defaults.bool(forKey: AppDefaultsKey.launchAtLogin))
}

@MainActor
@Test
func launchAtLoginToggleRegistersAndUnregistersThroughController() {
    let defaults = UserDefaults(suiteName: #function)!
    defaults.removePersistentDomain(forName: #function)

    let store = InMemoryPresetStore(presets: FactoryPresets.seedLibrary)
    let controller = TestLaunchAtLoginController(status: .notRegistered)
    let appState = AppState(store: store, userDefaults: defaults, launchAtLoginController: controller)

    appState.setLaunchAtLogin(true)
    #expect(controller.registerCallCount == 1)
    #expect(appState.launchAtLoginEnabled)
    #expect(defaults.bool(forKey: AppDefaultsKey.launchAtLogin))

    appState.setLaunchAtLogin(false)
    #expect(controller.unregisterCallCount == 1)
    #expect(appState.launchAtLoginEnabled == false)
    #expect(defaults.bool(forKey: AppDefaultsKey.launchAtLogin) == false)
}

private final class InMemoryPresetStore: PresetStoring {
    var presets: [Preset]
    var session: SessionSnapshot
    var savedPresets: [[Preset]] = []
    var savedSessions: [SessionSnapshot] = []

    init(presets: [Preset], session: SessionSnapshot = SessionSnapshot(activePresetID: nil, isBypassed: false)) {
        self.presets = presets
        self.session = session
    }

    func loadPresets() -> [Preset] {
        presets
    }

    func savePresets(_ presets: [Preset]) {
        self.presets = presets
        savedPresets.append(presets)
    }

    func loadSession() -> SessionSnapshot {
        session
    }

    func saveSession(activePresetID: UUID?, isBypassed: Bool) {
        session = SessionSnapshot(activePresetID: activePresetID, isBypassed: isBypassed)
        savedSessions.append(session)
    }
}

private final class TestLaunchAtLoginController: LaunchAtLoginControlling {
    var status: SMAppService.Status
    var registerCallCount = 0
    var unregisterCallCount = 0

    init(status: SMAppService.Status) {
        self.status = status
    }

    func register() throws {
        registerCallCount += 1
        status = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        status = .notRegistered
    }
}
