import Foundation

struct FilterParameters: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case dimming
        case brightness
        case contrast
        case gamma
        case saturation
        case temperature
        case overlayHue
        case overlaySaturation
        case overlayBrightness
        case overlayOpacity
    }

    var dimming: Double
    var brightness: Double
    var contrast: Double
    var gamma: Double
    var saturation: Double
    var temperature: Double
    var overlayHue: Double
    var overlaySaturation: Double
    var overlayBrightness: Double
    var overlayOpacity: Double

    init(
        dimming: Double,
        brightness: Double,
        contrast: Double,
        gamma: Double,
        saturation: Double,
        temperature: Double,
        overlayHue: Double,
        overlaySaturation: Double,
        overlayBrightness: Double,
        overlayOpacity: Double
    ) {
        self.dimming = dimming
        self.brightness = brightness
        self.contrast = contrast
        self.gamma = gamma
        self.saturation = saturation
        self.temperature = temperature
        self.overlayHue = overlayHue
        self.overlaySaturation = overlaySaturation
        self.overlayBrightness = overlayBrightness
        self.overlayOpacity = overlayOpacity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dimming = try container.decode(Double.self, forKey: .dimming)
        brightness = try container.decode(Double.self, forKey: .brightness)
        contrast = try container.decode(Double.self, forKey: .contrast)
        gamma = try container.decode(Double.self, forKey: .gamma)
        saturation = try container.decode(Double.self, forKey: .saturation)
        temperature = try container.decode(Double.self, forKey: .temperature)
        overlayHue = try container.decode(Double.self, forKey: .overlayHue)
        overlaySaturation = try container.decode(Double.self, forKey: .overlaySaturation)
        overlayBrightness = try container.decodeIfPresent(Double.self, forKey: .overlayBrightness) ?? 1.0
        overlayOpacity = try container.decode(Double.self, forKey: .overlayOpacity)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dimming, forKey: .dimming)
        try container.encode(brightness, forKey: .brightness)
        try container.encode(contrast, forKey: .contrast)
        try container.encode(gamma, forKey: .gamma)
        try container.encode(saturation, forKey: .saturation)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(overlayHue, forKey: .overlayHue)
        try container.encode(overlaySaturation, forKey: .overlaySaturation)
        try container.encode(overlayBrightness, forKey: .overlayBrightness)
        try container.encode(overlayOpacity, forKey: .overlayOpacity)
    }

    static let neutral = FilterParameters(
        dimming: 0,
        brightness: 0,
        contrast: 0,
        gamma: 1.0,
        saturation: 1.0,
        temperature: 0,
        overlayHue: 0,
        overlaySaturation: 0,
        overlayBrightness: 1.0,
        overlayOpacity: 0
    )
}
