import Foundation

enum FactoryPresets {
    static let neutralID = makeSeedID("8F2F64E7-1E6B-4A43-B2C4-9C177E8E6F21")

    static let neutralPreset = Preset(
        id: neutralID,
        name: "Neutro",
        createdAt: seedDate,
        parameters: .neutral,
        isLocked: true
    )

    static var seedLibrary: [Preset] {
        [
            Preset(
                id: makeSeedID("A6F2C0D1-4E3F-4A2C-8C29-4A71548A74AF"),
                name: "Noche",
                createdAt: seedDate,
                parameters: FilterParameters(
                    dimming: 0.3,
                    brightness: -0.1,
                    contrast: 0.1,
                    gamma: 1.2,
                    saturation: 0.7,
                    temperature: 0.7,
                    overlayHue: 0.08,
                    overlaySaturation: 0.8,
                    overlayBrightness: 1.0,
                    overlayOpacity: 0.15
                ),
                isLocked: false
            ),
            Preset(
                id: makeSeedID("7D0A2FA4-6880-4B61-A8F2-A602E8F6AC8B"),
                name: "Foco",
                createdAt: seedDate,
                parameters: FilterParameters(
                    dimming: 0.1,
                    brightness: 0,
                    contrast: 0.1,
                    gamma: 1.0,
                    saturation: 0.3,
                    temperature: 0.2,
                    overlayHue: 0,
                    overlaySaturation: 0,
                    overlayBrightness: 1.0,
                    overlayOpacity: 0
                ),
                isLocked: false
            ),
            Preset(
                id: makeSeedID("AC7B4E59-75A1-4AC1-AE4D-E72CE9CC65A6"),
                name: "Lectura",
                createdAt: seedDate,
                parameters: FilterParameters(
                    dimming: 0.2,
                    brightness: -0.05,
                    contrast: 0,
                    gamma: 1.1,
                    saturation: 0.85,
                    temperature: 0.4,
                    overlayHue: 0.11,
                    overlaySaturation: 0.18,
                    overlayBrightness: 1.0,
                    overlayOpacity: 0.08
                ),
                isLocked: false
            ),
            neutralPreset,
        ]
    }

    static func repairedLibrary(from presets: [Preset]) -> [Preset] {
        guard !presets.isEmpty else {
            return seedLibrary
        }

        var seenIDs = Set<UUID>()
        var editable: [Preset] = []

        for preset in presets {
            guard seenIDs.insert(preset.id).inserted else {
                continue
            }

            guard preset.id != neutralID else {
                continue
            }

            editable.append(
                Preset(
                    id: preset.id,
                    name: preset.name,
                    createdAt: preset.createdAt,
                    parameters: preset.parameters,
                    isLocked: false
                )
            )
        }

        return editable + [neutralPreset]
    }

    private static var seedDate: Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 4
        components.day = 1
        return components.date ?? .distantPast
    }

    private static func makeSeedID(_ rawValue: String) -> UUID {
        guard let uuid = UUID(uuidString: rawValue) else {
            preconditionFailure("Invalid factory preset UUID: \(rawValue)")
        }

        return uuid
    }
}
