import Foundation
import Testing
@testable import ColorLayer

@Test
func firstLaunchSeedsFactoryPresetsAndDefaultSession() throws {
    let context = try makePresetStoreContext()
    defer { context.cleanup() }

    let presets = context.store.loadPresets()
    let session = context.store.loadSession()

    #expect(presets.count == 4)
    #expect(presets.last?.id == FactoryPresets.neutralID)
    #expect(presets.last?.isLocked == true)
    #expect(session.activePresetID == nil)
    #expect(session.isBypassed == false)
    #expect(FileManager.default.fileExists(atPath: context.presetsFileURL.path))
}

@Test
func corruptJSONReseedsSilently() throws {
    let context = try makePresetStoreContext()
    defer { context.cleanup() }

    _ = context.store.loadPresets()
    try "not-json".data(using: .utf8)?.write(to: context.presetsFileURL, options: .atomic)

    let presets = context.store.loadPresets()

    #expect(presets == FactoryPresets.seedLibrary)
}

@Test
func legacyJSONWithoutOverlayBrightnessDefaultsToFullBrightness() throws {
    let context = try makePresetStoreContext()
    defer { context.cleanup() }

    let legacyJSON = """
    [
      {
        "createdAt" : "2026-04-01T00:00:00Z",
        "id" : "\(FactoryPresets.seedLibrary[0].id.uuidString)",
        "isLocked" : false,
        "name" : "Legacy",
        "parameters" : {
          "brightness" : -0.1,
          "contrast" : 0.1,
          "dimming" : 0.3,
          "gamma" : 1.2,
          "overlayHue" : 0.08,
          "overlayOpacity" : 0.15,
          "overlaySaturation" : 0.8,
          "saturation" : 0.7,
          "temperature" : 0.7
        }
      }
    ]
    """

    try FileManager.default.createDirectory(
        at: context.presetsFileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try legacyJSON.data(using: .utf8)?.write(to: context.presetsFileURL, options: .atomic)

    let presets = context.store.loadPresets()

    #expect(presets.first?.parameters.overlayBrightness == 1.0)
}

@Test
func sessionRoundTripPersistsActivePresetAndBypass() throws {
    let context = try makePresetStoreContext()
    defer { context.cleanup() }

    let activePresetID = FactoryPresets.seedLibrary.first?.id

    context.store.saveSession(activePresetID: activePresetID, isBypassed: true)

    #expect(
        context.store.loadSession() ==
            SessionSnapshot(activePresetID: activePresetID, isBypassed: true)
    )
}

@Test
func savePresetsRecreatesStorageDirectoryAfterExternalDeletion() throws {
    let context = try makePresetStoreContext()
    defer { context.cleanup() }

    _ = context.store.loadPresets()
    try FileManager.default.removeItem(at: context.storageDirectoryURL)

    context.store.savePresets(FactoryPresets.seedLibrary)

    #expect(FileManager.default.fileExists(atPath: context.storageDirectoryURL.path))
    #expect(FileManager.default.fileExists(atPath: context.presetsFileURL.path))
    #expect(context.store.loadPresets() == FactoryPresets.seedLibrary)
}

private func makePresetStoreContext() throws -> PresetStoreContext {
    let temporaryDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true, attributes: nil)

    let suiteName = "ColorLayerTests.\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!

    let store = PresetStore(
        fileManager: .default,
        userDefaults: userDefaults,
        baseDirectoryURL: temporaryDirectoryURL
    )

    let presetsFileURL = temporaryDirectoryURL
        .appendingPathComponent("ColorLayer", isDirectory: true)
        .appendingPathComponent("presets.json")
    let storageDirectoryURL = presetsFileURL.deletingLastPathComponent()

    return PresetStoreContext(
        store: store,
        storageDirectoryURL: storageDirectoryURL,
        presetsFileURL: presetsFileURL,
        suiteName: suiteName,
        temporaryDirectoryURL: temporaryDirectoryURL
    )
}

private struct PresetStoreContext {
    let store: PresetStore
    let storageDirectoryURL: URL
    let presetsFileURL: URL
    let suiteName: String
    let temporaryDirectoryURL: URL

    func cleanup() {
        if let userDefaults = UserDefaults(suiteName: suiteName) {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        try? FileManager.default.removeItem(at: temporaryDirectoryURL)
    }
}
