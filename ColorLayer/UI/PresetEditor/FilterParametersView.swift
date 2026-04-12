import AppKit
import SwiftUI

struct FilterParametersView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Group {
            if let activePreset = appState.activePreset {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            header(for: activePreset)

                            parameterSection("LUMINOSIDAD") {
                                sliderRow(
                                    title: "Dimming",
                                    value: Binding(
                                        get: { appState.liveParameters.dimming },
                                        set: { appState.liveParameters.dimming = $0 }
                                    ),
                                    range: 0 ... 0.8
                                )

                                sliderRow(
                                    title: "Brillo",
                                    value: Binding(
                                        get: { appState.liveParameters.brightness },
                                        set: { appState.liveParameters.brightness = $0 }
                                    ),
                                    range: -0.5 ... 0.5
                                )
                            }
                            .disabled(activePreset.isLocked)

                            parameterSection("CONTRASTE Y TONO") {
                                sliderRow(
                                    title: "Contraste",
                                    value: Binding(
                                        get: { appState.liveParameters.contrast },
                                        set: { appState.liveParameters.contrast = $0 }
                                    ),
                                    range: -0.5 ... 0.5
                                )

                                sliderRow(
                                    title: "Gamma",
                                    value: Binding(
                                        get: { appState.liveParameters.gamma },
                                        set: { appState.liveParameters.gamma = $0 }
                                    ),
                                    range: 0.5 ... 2.0
                                )

                                sliderRow(
                                    title: "Temperatura",
                                    value: Binding(
                                        get: { appState.liveParameters.temperature },
                                        set: { appState.liveParameters.temperature = $0 }
                                    ),
                                    range: -1 ... 1
                                )
                            }
                            .disabled(activePreset.isLocked)

                            parameterSection("OVERLAY") {
                                HStack(spacing: 12) {
                                    Text("Color")
                                    Spacer()
                                    ColorPicker("", selection: overlayColorBinding, supportsOpacity: false)
                                        .labelsHidden()
                                }

                                sliderRow(
                                    title: "Opacidad",
                                    value: Binding(
                                        get: { appState.liveParameters.overlayOpacity },
                                        set: { appState.liveParameters.overlayOpacity = $0 }
                                    ),
                                    range: 0 ... 0.6
                                )
                            }
                            .disabled(activePreset.isLocked)
                        }
                        .padding(20)
                    }

                    Divider()

                    HStack(spacing: 10) {
                        Button("Guardar") {
                            appState.saveActivePresetChanges()
                        }
                        .disabled(activePreset.isLocked || !appState.hasUnsavedChanges)

                        Button("Descartar") {
                            appState.discardActivePresetChanges()
                        }
                        .disabled(!appState.hasUnsavedChanges)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Selecciona un preset")
                        .font(.headline)
                    Text("Elige un preset en la columna izquierda para editarlo.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var overlayColorBinding: Binding<Color> {
        Binding(
            get: {
                Color(
                    hue: appState.liveParameters.overlayHue,
                    saturation: appState.liveParameters.overlaySaturation,
                    brightness: appState.liveParameters.overlayBrightness
                )
            },
            set: { newColor in
                guard let nsColor = NSColor(newColor).usingColorSpace(.deviceRGB) else {
                    return
                }

                var hue: CGFloat = 0
                var saturation: CGFloat = 0
                var brightness: CGFloat = 0
                var alpha: CGFloat = 0

                nsColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
                appState.liveParameters.overlayHue = Double(hue)
                appState.liveParameters.overlaySaturation = Double(saturation)
                appState.liveParameters.overlayBrightness = Double(brightness)
            }
        )
    }

    @ViewBuilder
    private func header(for preset: Preset) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(preset.name)
                .font(.title2)
                .fontWeight(.semibold)

            if preset.isLocked {
                Text("Preset bloqueado. Sus parámetros se muestran en solo lectura.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func parameterSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            content()
        }
    }

    @ViewBuilder
    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: range)
        }
    }
}
