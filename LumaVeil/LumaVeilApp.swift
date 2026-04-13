import AppKit
import Combine
import Dispatch
import SwiftUI

/// SwiftUI entry point for the LumaVeil menubar application.
@main
struct LumaVeilApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

/// AppKit lifecycle bridge that owns display recovery, overlay coordination and window presentation.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState.shared
    private var overlayWindowController: OverlayWindowController?
    private var presetEditorWindowController: PresetEditorWindowController?
    private var signalTerminationHandler: SignalTerminationHandler?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = DisplayEffectRecovery.recoverIfNeeded()
        AppLog.lifecycle.info("Application did finish launching.")
        overlayWindowController = OverlayWindowController(appState: appState)
        menuBarController = MenuBarController(appState: appState, appDelegate: self)
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

@MainActor
private final class MenuBarController: NSObject {
    private let appState: AppState
    private weak var appDelegate: AppDelegate?
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let contextMenu = NSMenu()
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState, appDelegate: AppDelegate) {
        self.appState = appState
        self.appDelegate = appDelegate
        // Keep a fixed status item slot so popover anchoring does not shift when the symbol changes.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureStatusItem()
        configurePopover()
        configureContextMenu()
        observeAppState()
        updateStatusItemImage()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.imagePosition = .imageOnly
        button.toolTip = "LumaVeil"
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 280, height: 320)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPanelView(appState: appState)
                .environment(\.showPresetEditorAction, { [weak self] in
                    self?.showPresetEditor()
                })
                .environment(\.closeMenuBarPanelAction, { [weak self] in
                    self?.popover.performClose(nil)
                })
        )
    }

    private func configureContextMenu() {
        let editItem = NSMenuItem(
            title: "Edit Presets...",
            action: #selector(editPresetsSelected),
            keyEquivalent: ""
        )
        editItem.target = self
        contextMenu.addItem(editItem)

        contextMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit LumaVeil",
            action: #selector(quitSelected),
            keyEquivalent: ""
        )
        quitItem.target = self
        contextMenu.addItem(quitItem)
    }

    private func observeAppState() {
        appState.$isBypassed
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItemImage()
            }
            .store(in: &cancellables)
    }

    private func updateStatusItemImage() {
        guard let button = statusItem.button else {
            return
        }

        let image = NSImage(
            systemSymbolName: appState.menuBarSymbolName,
            accessibilityDescription: "LumaVeil"
        )
        image?.isTemplate = true
        button.image = image
    }

    @objc
    private func handleStatusItemClick(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        switch event.type {
        case .rightMouseUp:
            showContextMenu()
        case .leftMouseUp:
            togglePopover()
        default:
            break
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        }

        statusItem.menu = contextMenu
        button.performClick(nil)
        statusItem.menu = nil
    }

    private func showPresetEditor() {
        appDelegate?.showPresetEditor()
        popover.performClose(nil)
    }

    @objc
    private func editPresetsSelected() {
        showPresetEditor()
    }

    @objc
    private func quitSelected() {
        NSApplication.shared.terminate(nil)
    }
}

private final class SignalTerminationHandler {
    private let queue = DispatchQueue(label: "LumaVeil.SignalTerminationHandler")
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
