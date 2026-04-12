import SwiftUI

struct PresetEditorView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            PresetListView(appState: appState)
                .frame(width: 220)

            Divider()
                .accessibilityHidden(true)

            FilterParametersView(appState: appState)
        }
        .frame(width: 640, height: 480)
        .accessibilityElement(children: .contain)
    }
}
