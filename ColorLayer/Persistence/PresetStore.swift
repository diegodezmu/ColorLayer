import Foundation

struct SessionSnapshot: Equatable {
    var activePresetID: UUID?
    var isBypassed: Bool
}

enum AppDefaultsKey {
    static let activePresetID = "colorlayer.activePresetID"
    static let isBypassed = "colorlayer.isBypassed"
    static let effectActive = "colorlayer.effectActive"
    static let launchAtLogin = "colorlayer.launchAtLogin"
}

/// Persists the preset library and lightweight session state used to restore the menubar UI.
protocol PresetStoring {
    /// Loads the preset library from storage, repairing or reseeding it when persistence is unavailable.
    func loadPresets() -> [Preset]

    /// Saves the preset library snapshot to storage.
    func savePresets(_ presets: [Preset])

    /// Loads the last persisted session state for the active preset and bypass toggle.
    func loadSession() -> SessionSnapshot

    /// Saves the lightweight session state needed to restore the active preset and bypass toggle.
    func saveSession(activePresetID: UUID?, isBypassed: Bool)
}

final class PresetStore: PresetStoring {
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
        } else if let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            rootDirectory = applicationSupportURL
        } else {
            AppLog.persistence.error("Application Support directory could not be resolved. Falling back to the user's Library/Application Support directory.")
            rootDirectory = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
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
        let presetsFilePath = presetsFileURL.path

        do {
            try ensureStorageDirectory()
        } catch {
            AppLog.persistence.error("Failed to create preset storage directory before reading presets: \(error.localizedDescription, privacy: .public)")
            return reseedFactoryPresets()
        }

        guard fileManager.fileExists(atPath: presetsFileURL.path) else {
            AppLog.persistence.debug("No presets file found at \(presetsFilePath, privacy: .public). Seeding factory presets.")
            return reseedFactoryPresets()
        }

        do {
            let data = try Data(contentsOf: presetsFileURL)
            let decodedPresets = try decoder.decode([Preset].self, from: data)

            guard !decodedPresets.isEmpty else {
                AppLog.persistence.error("Presets file at \(presetsFilePath, privacy: .public) was empty. Reseeding factory presets.")
                return reseedFactoryPresets()
            }

            let repairedPresets = FactoryPresets.repairedLibrary(from: decodedPresets)
            if repairedPresets != decodedPresets {
                AppLog.persistence.debug("Preset library required repair after loading from \(presetsFilePath, privacy: .public).")
                savePresets(repairedPresets)
            }

            return repairedPresets
        } catch {
            AppLog.persistence.error("Failed to read presets from \(presetsFilePath, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return reseedFactoryPresets()
        }
    }

    func savePresets(_ presets: [Preset]) {
        let presetsFilePath = presetsFileURL.path

        do {
            try ensureStorageDirectory()
            let data = try encoder.encode(FactoryPresets.repairedLibrary(from: presets))
            try data.write(to: presetsFileURL, options: .atomic)
        } catch {
            AppLog.persistence.error("Failed to write presets to \(presetsFilePath, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    func loadSession() -> SessionSnapshot {
        let activePresetID = userDefaults.string(forKey: AppDefaultsKey.activePresetID).flatMap(UUID.init(uuidString:))
        return SessionSnapshot(
            activePresetID: activePresetID,
            isBypassed: userDefaults.bool(forKey: AppDefaultsKey.isBypassed)
        )
    }

    func saveSession(activePresetID: UUID?, isBypassed: Bool) {
        if let activePresetID {
            userDefaults.set(activePresetID.uuidString, forKey: AppDefaultsKey.activePresetID)
        } else {
            userDefaults.removeObject(forKey: AppDefaultsKey.activePresetID)
        }

        userDefaults.set(isBypassed, forKey: AppDefaultsKey.isBypassed)
    }

    private func ensureStorageDirectory() throws {
        try fileManager.createDirectory(at: storageDirectoryURL, withIntermediateDirectories: true, attributes: nil)
    }

    private func reseedFactoryPresets() -> [Preset] {
        let seededPresets = FactoryPresets.seedLibrary
        savePresets(seededPresets)
        return seededPresets
    }
}
