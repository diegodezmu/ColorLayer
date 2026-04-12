import AppKit
import CoreGraphics
import Dispatch
import SwiftUI

@main
struct ColorLayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra("ColorLayer", systemImage: appState.menuBarSymbolName) {
            MenuBarPanelView(appState: appState)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?

    private let appState = AppState.shared
    private var overlayWindowController: OverlayWindowController?
    private var presetEditorWindowController: PresetEditorWindowController?
    private var signalTerminationHandler: SignalTerminationHandler?

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        CGDisplayRestoreColorSyncSettings()
        overlayWindowController = OverlayWindowController(appState: appState)
        signalTerminationHandler = SignalTerminationHandler { [weak self] _ in
            Task { @MainActor in
                self?.handleTerminationSignal()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        overlayWindowController?.restoreSystemState()
        signalTerminationHandler?.invalidate()
    }

    func showPresetEditor() {
        if presetEditorWindowController == nil {
            presetEditorWindowController = PresetEditorWindowController(appState: appState)
        }

        presetEditorWindowController?.showWindow(nil)
        presetEditorWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func handleTerminationSignal() {
        overlayWindowController?.restoreSystemState()
        signalTerminationHandler?.invalidate()
        NSApp.terminate(nil)
    }
}

private final class SignalTerminationHandler {
    private let queue = DispatchQueue(label: "ColorLayer.SignalTerminationHandler")
    private let signals: [Int32]
    private var sources: [DispatchSourceSignal] = []
    private let handler: @Sendable (Int32) -> Void

    init(signals: [Int32] = [SIGTERM, SIGINT], handler: @escaping @Sendable (Int32) -> Void) {
        self.signals = signals
        self.handler = handler
        installSources()
    }

    func invalidate() {
        guard !sources.isEmpty else {
            return
        }

        sources.forEach { $0.cancel() }
        sources.removeAll()
        signals.forEach { Darwin.signal($0, SIG_DFL) }
    }

    private func installSources() {
        for signalNumber in signals {
            Darwin.signal(signalNumber, SIG_IGN)

            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: queue)
            source.setEventHandler { [weak self] in
                self?.invalidate()
                self?.handler(signalNumber)
            }
            source.resume()
            sources.append(source)
        }
    }
}
