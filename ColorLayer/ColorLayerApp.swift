import AppKit
import Dispatch
import SwiftUI

/// SwiftUI entry point for the ColorLayer menubar application.
@main
struct ColorLayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra("ColorLayer", systemImage: appState.menuBarSymbolName) {
            MenuBarPanelView(appState: appState)
                .environment(\.showPresetEditorAction, {
                    appDelegate.showPresetEditor()
                })
        }
        .menuBarExtraStyle(.window)
    }
}

/// AppKit lifecycle bridge that owns display recovery, overlay coordination and window presentation.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState.shared
    private var overlayWindowController: OverlayWindowController?
    private var presetEditorWindowController: PresetEditorWindowController?
    private var signalTerminationHandler: SignalTerminationHandler?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = DisplayEffectRecovery.recoverIfNeeded()
        AppLog.lifecycle.info("Application did finish launching.")
        overlayWindowController = OverlayWindowController(appState: appState)
        signalTerminationHandler = SignalTerminationHandler { [weak self] signalNumber in
            Task { @MainActor in
                self?.handleTerminationSignal(signalNumber)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppLog.lifecycle.info("Application will terminate.")
        overlayWindowController?.restoreSystemState()
        signalTerminationHandler?.invalidate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showPresetEditor() {
        if presetEditorWindowController == nil {
            presetEditorWindowController = PresetEditorWindowController(appState: appState)
        }

        presetEditorWindowController?.showWindow(nil)
        presetEditorWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func handleTerminationSignal(_ signalNumber: Int32) {
        AppLog.lifecycle.info(
            "Received termination signal \(Self.signalName(for: signalNumber), privacy: .public) (\(signalNumber, privacy: .public)). Restoring system state before termination."
        )
        overlayWindowController?.restoreSystemState()
        signalTerminationHandler?.invalidate()
        NSApp.terminate(nil)
    }

    private static func signalName(for signalNumber: Int32) -> String {
        switch signalNumber {
        case SIGTERM:
            return "SIGTERM"
        case SIGINT:
            return "SIGINT"
        default:
            return "SIGNAL"
        }
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

        AppLog.lifecycle.debug("Invalidating signal termination handlers.")
        sources.forEach { $0.cancel() }
        sources.removeAll()
        signals.forEach { Darwin.signal($0, SIG_DFL) }
    }

    private func installSources() {
        for signalNumber in signals {
            Darwin.signal(signalNumber, SIG_IGN)
            AppLog.lifecycle.debug("Installing signal handler for \(signalNumber, privacy: .public).")

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
