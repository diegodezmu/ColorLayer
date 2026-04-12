import Foundation

struct SessionSnapshot: Equatable {
    var activePresetID: UUID?
    var isBypassed: Bool
}

protocol PresetStoring {
    func loadPresets() -> [Preset]
    func savePresets(_ presets: [Preset])
    func loadSession() -> SessionSnapshot
    func saveSession(activePresetID: UUID?, isBypassed: Bool)
}

final class PresetStore: PresetStoring {
    private enum Keys {
        static let activePresetID = "colorlayer.activePresetID"
        static let isBypassed = "colorlayer.isBypassed"
    }

    private let fileManager: FileManager
    private let userDefaults: UserDefaults
    private let storageDirectoryURL: URL
    private let presetsFileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard,
        baseDirectoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.userDefaults = userDefaults

        let rootDirectory: URL
        if let baseDirectoryURL {
            rootDirectory = baseDirectoryURL
        } else {
            rootDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        }

        storageDirectoryURL = rootDirectory.appendingPathComponent("ColorLayer", isDirectory: true)
        presetsFileURL = storageDirectoryURL.appendingPathComponent("presets.json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadPresets() -> [Preset] {
        try? ensureStorageDirectory()

        guard
            let data = try? Data(contentsOf: presetsFileURL),
            let decodedPresets = try? decoder.decode([Preset].self, from: data),
            !decodedPresets.isEmpty
        else {
            let seededPresets = FactoryPresets.seedLibrary
            savePresets(seededPresets)
            return seededPresets
        }

        let repairedPresets = FactoryPresets.repairedLibrary(from: decodedPresets)
        if repairedPresets != decodedPresets {
            savePresets(repairedPresets)
        }

        return repairedPresets
    }

    func savePresets(_ presets: [Preset]) {
        do {
            try ensureStorageDirectory()
            let data = try encoder.encode(FactoryPresets.repairedLibrary(from: presets))
            try data.write(to: presetsFileURL, options: .atomic)
        } catch {
            assertionFailure("Failed to save presets: \(error)")
        }
    }

    func loadSession() -> SessionSnapshot {
        let activePresetID = userDefaults.string(forKey: Keys.activePresetID).flatMap(UUID.init(uuidString:))
        return SessionSnapshot(
            activePresetID: activePresetID,
            isBypassed: userDefaults.bool(forKey: Keys.isBypassed)
        )
    }

    func saveSession(activePresetID: UUID?, isBypassed: Bool) {
        if let activePresetID {
            userDefaults.set(activePresetID.uuidString, forKey: Keys.activePresetID)
        } else {
            userDefaults.removeObject(forKey: Keys.activePresetID)
        }

        userDefaults.set(isBypassed, forKey: Keys.isBypassed)
    }

    private func ensureStorageDirectory() throws {
        try fileManager.createDirectory(at: storageDirectoryURL, withIntermediateDirectories: true, attributes: nil)
    }
}
