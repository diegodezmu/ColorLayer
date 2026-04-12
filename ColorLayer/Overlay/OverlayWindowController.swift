import AppKit
import Combine

@MainActor
final class OverlayWindowController: NSWindowController {
    private let appState: AppState
    private let overlayView = OverlayView(frame: .zero)
    private let displayTransferController: DisplayTransferController
    nonisolated(unsafe) private var screenParametersObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState, displayTransferController: DisplayTransferController = DisplayTransferController()) {
        self.appState = appState
        self.displayTransferController = displayTransferController

        let window = OverlayWindow(
            contentRect: NSScreen.main?.frame ?? .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)
        configureWindow(window)
        registerForScreenChanges()
        observeAppState()
        syncFromObservedState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
        }
    }

    func showOverlay() {
        guard let window else {
            return
        }

        if let frame = NSScreen.main?.frame {
            window.setFrame(frame, display: true)
        }

        window.orderFront(nil)
    }

    func hideOverlay() {
        window?.orderOut(nil)
    }

    func apply(parameters: FilterParameters) {
        overlayView.update(with: parameters)
    }

    func handleScreenParametersChange() {
        if let frame = NSScreen.main?.frame {
            window?.setFrame(frame, display: true)
        }

        displayTransferController.handleDisplayConfigurationChange(
            parameters: appState.liveParameters,
            isBypassed: appState.isBypassed
        )
    }

    func restoreSystemState() {
        hideOverlay()
        displayTransferController.restoreSystemState()
    }

    private func configureWindow(_ window: NSWindow) {
        window.backgroundColor = .clear
        window.isOpaque = false
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.contentView = overlayView
    }

    private func registerForScreenChanges() {
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleScreenParametersChange()
            }
        }
    }

    private func observeAppState() {
        appState.$liveParameters
            .combineLatest(appState.$isBypassed)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.syncFromObservedState()
            }
            .store(in: &cancellables)
    }

    private func syncFromObservedState() {
        apply(parameters: appState.liveParameters)
        displayTransferController.sync(
            parameters: appState.liveParameters,
            isBypassed: appState.isBypassed
        )

        if appState.isBypassed {
            hideOverlay()
        } else {
            showOverlay()
        }
    }
}

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
