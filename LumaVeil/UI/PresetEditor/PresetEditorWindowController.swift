import AppKit
import SwiftUI

@MainActor
final class PresetEditorWindowController: NSWindowController, NSWindowDelegate {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        window.title = "Editar presets"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 640, height: 500)
        window.maxSize = NSSize(width: 640, height: 500)
        window.center()
        window.delegate = self
        contentViewController = NSHostingController(rootView: PresetEditorView(appState: appState))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        appState.discardActivePresetChanges()
        sender.orderOut(nil)
        return false
    }
}
