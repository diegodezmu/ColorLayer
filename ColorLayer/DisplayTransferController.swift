import CoreGraphics

struct DisplayTransferTable: Equatable {
    let red: [CGGammaValue]
    let green: [CGGammaValue]
    let blue: [CGGammaValue]

    init(red: [CGGammaValue], green: [CGGammaValue], blue: [CGGammaValue]) {
        precondition(red.count == green.count && green.count == blue.count, "Gamma channels must have identical sample counts.")
        self.red = red
        self.green = green
        self.blue = blue
    }

    var sampleCount: Int {
        red.count
    }

    static func linear(sampleCount: Int) -> DisplayTransferTable {
        precondition(sampleCount > 0, "Gamma tables must contain at least one sample.")

        let denominator = max(sampleCount - 1, 1)
        let values = (0 ..< sampleCount).map { index in
            CGGammaValue(index) / CGGammaValue(denominator)
        }

        return DisplayTransferTable(red: values, green: values, blue: values)
    }
}

protocol DisplayTransferHardware {
    func restoreColorSyncSettings()
    func mainDisplayID() -> CGDirectDisplayID?
    func gammaTableCapacity(for displayID: CGDirectDisplayID) -> UInt32
    func currentTransferTable(for displayID: CGDirectDisplayID) -> DisplayTransferTable?
    @discardableResult
    func setTransferTable(_ table: DisplayTransferTable, for displayID: CGDirectDisplayID) -> Bool
}

struct CoreGraphicsDisplayTransferHardware: DisplayTransferHardware {
    func restoreColorSyncSettings() {
        CGDisplayRestoreColorSyncSettings()
    }

    func mainDisplayID() -> CGDirectDisplayID? {
        let displayID = CGMainDisplayID()
        return displayID == 0 ? nil : displayID
    }

    func gammaTableCapacity(for displayID: CGDirectDisplayID) -> UInt32 {
        CGDisplayGammaTableCapacity(displayID)
    }

    func currentTransferTable(for displayID: CGDirectDisplayID) -> DisplayTransferTable? {
        let capacity = gammaTableCapacity(for: displayID)
        guard capacity > 0 else {
            return nil
        }

        var red = Array(repeating: CGGammaValue.zero, count: Int(capacity))
        var green = Array(repeating: CGGammaValue.zero, count: Int(capacity))
        var blue = Array(repeating: CGGammaValue.zero, count: Int(capacity))
        var sampleCount: UInt32 = 0

        let error = red.withUnsafeMutableBufferPointer { redBuffer in
            green.withUnsafeMutableBufferPointer { greenBuffer in
                blue.withUnsafeMutableBufferPointer { blueBuffer in
                    CGGetDisplayTransferByTable(
                        displayID,
                        capacity,
                        redBuffer.baseAddress,
                        greenBuffer.baseAddress,
                        blueBuffer.baseAddress,
                        &sampleCount
                    )
                }
            }
        }

        guard error == .success, sampleCount > 0 else {
            return nil
        }

        let endIndex = Int(sampleCount)
        return DisplayTransferTable(
            red: Array(red.prefix(endIndex)),
            green: Array(green.prefix(endIndex)),
            blue: Array(blue.prefix(endIndex))
        )
    }

    @discardableResult
    func setTransferTable(_ table: DisplayTransferTable, for displayID: CGDirectDisplayID) -> Bool {
        guard table.sampleCount > 0 else {
            return false
        }

        return table.red.withUnsafeBufferPointer { redBuffer in
            table.green.withUnsafeBufferPointer { greenBuffer in
                table.blue.withUnsafeBufferPointer { blueBuffer in
                    CGSetDisplayTransferByTable(
                        displayID,
                        UInt32(table.sampleCount),
                        redBuffer.baseAddress,
                        greenBuffer.baseAddress,
                        blueBuffer.baseAddress
                    ) == .success
                }
            }
        }
    }
}

struct DisplayTransferTableBuilder {
    func makeTable(from parameters: FilterParameters, baseline: DisplayTransferTable) -> DisplayTransferTable {
        guard hasSignalAdjustments(parameters) else {
            return baseline
        }

        let brightnessOffset = CGGammaValue(parameters.brightness)
        let contrastScale = max(CGGammaValue(0.01), CGGammaValue(1.0 + parameters.contrast))
        let gammaPower = max(CGGammaValue(0.01), CGGammaValue(parameters.gamma))
        let temperatureGains = channelTemperatureGains(for: parameters.temperature)

        return DisplayTransferTable(
            red: baseline.red.map {
                transform(
                    $0,
                    brightnessOffset: brightnessOffset,
                    contrastScale: contrastScale,
                    gammaPower: gammaPower,
                    temperatureGain: temperatureGains.red
                )
            },
            green: baseline.green.map {
                transform(
                    $0,
                    brightnessOffset: brightnessOffset,
                    contrastScale: contrastScale,
                    gammaPower: gammaPower,
                    temperatureGain: temperatureGains.green
                )
            },
            blue: baseline.blue.map {
                transform(
                    $0,
                    brightnessOffset: brightnessOffset,
                    contrastScale: contrastScale,
                    gammaPower: gammaPower,
                    temperatureGain: temperatureGains.blue
                )
            }
        )
    }

    private func hasSignalAdjustments(_ parameters: FilterParameters) -> Bool {
        parameters.brightness != 0 ||
            parameters.contrast != 0 ||
            parameters.gamma != 1.0 ||
            parameters.temperature != 0
    }

    private func transform(
        _ input: CGGammaValue,
        brightnessOffset: CGGammaValue,
        contrastScale: CGGammaValue,
        gammaPower: CGGammaValue,
        temperatureGain: CGGammaValue
    ) -> CGGammaValue {
        let contrasted = ((clamp(input + brightnessOffset) - 0.5) * contrastScale) + 0.5
        let gammaAdjusted = pow(clamp(contrasted), gammaPower)
        return clamp(gammaAdjusted * temperatureGain)
    }

    private func channelTemperatureGains(for normalizedTemperature: Double) -> (red: CGGammaValue, green: CGGammaValue, blue: CGGammaValue) {
        let temperature = max(CGGammaValue(-1), min(CGGammaValue(1), CGGammaValue(normalizedTemperature)))

        if temperature >= 0 {
            return (
                red: 1.0 + (0.18 * temperature),
                green: 1.0 + (0.04 * temperature),
                blue: 1.0 - (0.18 * temperature)
            )
        }

        let magnitude = abs(temperature)
        return (
            red: 1.0 - (0.18 * magnitude),
            green: 1.0 + (0.02 * magnitude),
            blue: 1.0 + (0.18 * magnitude)
        )
    }

    private func clamp(_ value: CGGammaValue) -> CGGammaValue {
        min(max(value, 0), 1)
    }
}

@MainActor
final class DisplayTransferController {
    private let hardware: any DisplayTransferHardware
    private let tableBuilder: DisplayTransferTableBuilder

    private var trackedDisplayID: CGDirectDisplayID?
    private var baselineTable: DisplayTransferTable?
    private var hasCustomTransferTable = false

    init(
        hardware: any DisplayTransferHardware = CoreGraphicsDisplayTransferHardware(),
        tableBuilder: DisplayTransferTableBuilder = DisplayTransferTableBuilder()
    ) {
        self.hardware = hardware
        self.tableBuilder = tableBuilder
    }

    func sync(parameters: FilterParameters, isBypassed: Bool) {
        guard let displayID = ensureTrackedDisplay(), let baselineTable else {
            return
        }

        if isBypassed {
            _ = restoreActiveDisplay()
            return
        }

        let table = tableBuilder.makeTable(from: parameters, baseline: baselineTable)
        guard table != baselineTable else {
            _ = restoreActiveDisplay()
            return
        }

        guard hardware.setTransferTable(table, for: displayID) else {
            hardware.restoreColorSyncSettings()
            hasCustomTransferTable = false
            return
        }

        hasCustomTransferTable = true
    }

    func handleDisplayConfigurationChange(parameters: FilterParameters, isBypassed: Bool) {
        sync(parameters: parameters, isBypassed: isBypassed)
    }

    func restoreSystemState() {
        let restoredBaseline = restoreActiveDisplay()
        if !restoredBaseline {
            hardware.restoreColorSyncSettings()
        }

        trackedDisplayID = nil
        baselineTable = nil
        hasCustomTransferTable = false
    }

    private func ensureTrackedDisplay() -> CGDirectDisplayID? {
        let currentDisplayID = hardware.mainDisplayID()

        if trackedDisplayID != currentDisplayID {
            resetTrackedDisplay()
        }

        if let trackedDisplayID {
            return trackedDisplayID
        }

        guard
            let currentDisplayID,
            let baselineTable = hardware.currentTransferTable(for: currentDisplayID)
        else {
            return nil
        }

        trackedDisplayID = currentDisplayID
        self.baselineTable = baselineTable
        hasCustomTransferTable = false
        return currentDisplayID
    }

    private func resetTrackedDisplay() {
        let restoredBaseline = restoreActiveDisplay()
        if !restoredBaseline, trackedDisplayID != nil {
            hardware.restoreColorSyncSettings()
        }

        trackedDisplayID = nil
        baselineTable = nil
        hasCustomTransferTable = false
    }

    @discardableResult
    private func restoreActiveDisplay() -> Bool {
        guard let trackedDisplayID, let baselineTable else {
            return false
        }

        guard hasCustomTransferTable else {
            return true
        }

        let didRestore = hardware.setTransferTable(baselineTable, for: trackedDisplayID)
        if didRestore {
            hasCustomTransferTable = false
        }

        return didRestore
    }
}
