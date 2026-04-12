import CoreGraphics
import Foundation
import Testing
@testable import ColorLayer

@Test
func neutralParametersPreserveBaselineTable() {
    let builder = DisplayTransferTableBuilder()
    let baseline = DisplayTransferTable.linear(sampleCount: 8)

    let table = builder.makeTable(from: .neutral, baseline: baseline)

    #expect(table == baseline)
}

@Test
func brightnessShiftsTheMidtonesWithoutBreakingMonotonicity() {
    let builder = DisplayTransferTableBuilder()
    var parameters = FilterParameters.neutral
    parameters.brightness = 0.2

    let table = builder.makeTable(from: parameters, baseline: .linear(sampleCount: 8))

    #expect(table.red[4] > DisplayTransferTable.linear(sampleCount: 8).red[4])
    #expect(isMonotonic(table.red))
    #expect(isMonotonic(table.green))
    #expect(isMonotonic(table.blue))
}

@Test
func gammaAltersCurvePowerConsistently() {
    let builder = DisplayTransferTableBuilder()
    var parameters = FilterParameters.neutral
    parameters.gamma = 1.6
    let baseline = DisplayTransferTable.linear(sampleCount: 8)

    let table = builder.makeTable(from: parameters, baseline: baseline)

    #expect(table.red[4] < baseline.red[4])
    #expect(table.green[4] < baseline.green[4])
    #expect(table.blue[4] < baseline.blue[4])
}

@Test
func contrastRemapsTheMidpointCorrectly() {
    let builder = DisplayTransferTableBuilder()
    var parameters = FilterParameters.neutral
    parameters.contrast = 0.4
    let baseline = DisplayTransferTable.linear(sampleCount: 9)

    let table = builder.makeTable(from: parameters, baseline: baseline)

    #expect(table.red[2] < baseline.red[2])
    #expect(table.red[6] > baseline.red[6])
}

@Test
func temperatureBiasesChannelsInExpectedDirection() {
    let builder = DisplayTransferTableBuilder()
    var parameters = FilterParameters.neutral
    parameters.temperature = 1.0
    let baseline = DisplayTransferTable.linear(sampleCount: 8)

    let table = builder.makeTable(from: parameters, baseline: baseline)

    #expect(table.red[4] > baseline.red[4])
    #expect(table.blue[4] < baseline.blue[4])
}

@MainActor
@Test
func controllerCapturesBaselineOnlyOncePerDisplay() {
    let hardware = FakeDisplayTransferHardware()
    let controller = DisplayTransferController(hardware: hardware)
    var parameters = FilterParameters.neutral
    parameters.brightness = 0.1

    controller.sync(parameters: parameters, isBypassed: false)
    controller.sync(parameters: parameters, isBypassed: false)

    #expect(hardware.currentTransferTableRequests[1] == 1)
}

@MainActor
@Test
func controllerRestoresBaselineWhenBypassed() {
    let hardware = FakeDisplayTransferHardware()
    let controller = DisplayTransferController(hardware: hardware)
    var parameters = FilterParameters.neutral
    parameters.gamma = 1.4

    controller.sync(parameters: parameters, isBypassed: false)
    controller.sync(parameters: parameters, isBypassed: true)

    #expect(hardware.setOperations.count == 2)
    #expect(hardware.setOperations.last?.displayID == 1)
    #expect(hardware.setOperations.last?.table == hardware.baselines[1])
}

@MainActor
@Test
func controllerReappliesTableAfterBypassIsDisabled() {
    let hardware = FakeDisplayTransferHardware()
    let controller = DisplayTransferController(hardware: hardware)
    var parameters = FilterParameters.neutral
    parameters.temperature = 0.6

    controller.sync(parameters: parameters, isBypassed: false)
    controller.sync(parameters: parameters, isBypassed: true)
    controller.sync(parameters: parameters, isBypassed: false)

    #expect(hardware.setOperations.count == 3)
    #expect(hardware.setOperations.last?.table != hardware.baselines[1])
}

@MainActor
@Test
func controllerRestoresPreviousDisplayBeforeCapturingNewMainDisplay() {
    let hardware = FakeDisplayTransferHardware()
    let controller = DisplayTransferController(hardware: hardware)
    var parameters = FilterParameters.neutral
    parameters.brightness = -0.1

    controller.sync(parameters: parameters, isBypassed: false)
    hardware.mainDisplayIDValue = 2

    controller.handleDisplayConfigurationChange(parameters: parameters, isBypassed: false)

    #expect(hardware.currentTransferTableRequests[1] == 1)
    #expect(hardware.currentTransferTableRequests[2] == 1)
    #expect(hardware.setOperations.map(\.displayID) == [1, 1, 2])
    #expect(hardware.setOperations[1].table == hardware.baselines[1])
}

@MainActor
@Test
func controllerTracksDirtyShutdownFlagWhileCustomTransferTableIsActive() {
    let suiteName = "ColorLayerTests.DisplayTransferController.\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer { userDefaults.removePersistentDomain(forName: suiteName) }

    let hardware = FakeDisplayTransferHardware()
    let controller = DisplayTransferController(hardware: hardware, userDefaults: userDefaults)
    var parameters = FilterParameters.neutral
    parameters.gamma = 1.4

    controller.sync(parameters: parameters, isBypassed: false)
    #expect(userDefaults.bool(forKey: AppDefaultsKey.effectActive) == true)

    controller.sync(parameters: parameters, isBypassed: true)
    #expect(userDefaults.bool(forKey: AppDefaultsKey.effectActive) == false)
}

@Test
func dirtyShutdownRecoveryRestoresColorSyncAndClearsTheFlag() {
    let suiteName = "ColorLayerTests.DisplayRecovery.\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer { userDefaults.removePersistentDomain(forName: suiteName) }

    let hardware = FakeDisplayTransferHardware()
    userDefaults.set(true, forKey: AppDefaultsKey.effectActive)

    let didRecover = DisplayEffectRecovery.recoverIfNeeded(userDefaults: userDefaults, hardware: hardware)

    #expect(didRecover == true)
    #expect(hardware.restoreColorSyncCallCount == 1)
    #expect(userDefaults.bool(forKey: AppDefaultsKey.effectActive) == false)
}

private func isMonotonic(_ values: [CGGammaValue]) -> Bool {
    zip(values, values.dropFirst()).allSatisfy { pair in
        pair.0 <= pair.1
    }
}

private final class FakeDisplayTransferHardware: DisplayTransferHardware {
    var mainDisplayIDValue: CGDirectDisplayID? = 1
    var baselines: [CGDirectDisplayID: DisplayTransferTable] = [
        1: .linear(sampleCount: 8),
        2: .linear(sampleCount: 8),
    ]
    var currentTransferTableRequests: [CGDirectDisplayID: Int] = [:]
    var setOperations: [(displayID: CGDirectDisplayID, table: DisplayTransferTable)] = []
    var restoreColorSyncCallCount = 0

    func restoreColorSyncSettings() {
        restoreColorSyncCallCount += 1
    }

    func mainDisplayID() -> CGDirectDisplayID? {
        mainDisplayIDValue
    }

    func gammaTableCapacity(for displayID: CGDirectDisplayID) -> UInt32 {
        UInt32(baselines[displayID]?.sampleCount ?? 0)
    }

    func currentTransferTable(for displayID: CGDirectDisplayID) -> DisplayTransferTable? {
        currentTransferTableRequests[displayID, default: 0] += 1
        return baselines[displayID]
    }

    @discardableResult
    func setTransferTable(_ table: DisplayTransferTable, for displayID: CGDirectDisplayID) -> Bool {
        setOperations.append((displayID, table))
        return true
    }
}
