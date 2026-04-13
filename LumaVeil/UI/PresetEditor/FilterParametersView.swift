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

                            parameterSection("LUMINOSIDAD", accessibilityLabel: "Brightness section") {
                                sliderRow(
                                    title: "Dimming",
                                    accessibilityLabel: "Dimming level",
                                    value: Binding(
                                        get: { appState.liveParameters.dimming },
                                        set: { appState.liveParameters.dimming = $0 }
                                    ),
                                    range: 0 ... 0.8,
                                    accessibilityValue: percentageValueString
                                )

                                sliderRow(
                                    title: "Brillo",
                                    accessibilityLabel: "Brightness level",
                                    value: Binding(
                                        get: { appState.liveParameters.brightness },
                                        set: { appState.liveParameters.brightness = $0 }
                                    ),
                                    range: -0.5 ... 0.5,
                                    accessibilityValue: signedPercentageValueString
                                )
                            }
                            .disabled(activePreset.isLocked)

                            parameterSection("CONTRASTE Y TONO", accessibilityLabel: "Contrast and tone section") {
                                sliderRow(
                                    title: "Contraste",
                                    accessibilityLabel: "Contrast level",
                                    value: Binding(
                                        get: { appState.liveParameters.contrast },
                                        set: { appState.liveParameters.contrast = $0 }
                                    ),
                                    range: -0.5 ... 0.5,
                                    accessibilityValue: signedPercentageValueString
                                )

                                sliderRow(
                                    title: "Gamma",
                                    accessibilityLabel: "Gamma level",
                                    value: Binding(
                                        get: { appState.liveParameters.gamma },
                                        set: { appState.liveParameters.gamma = $0 }
                                    ),
                                    range: 0.5 ... 2.0,
                                    accessibilityValue: gammaValueString
                                )

                                sliderRow(
                                    title: "Temperatura",
                                    accessibilityLabel: "Temperature level",
                                    value: Binding(
                                        get: { appState.liveParameters.temperature },
                                        set: { appState.liveParameters.temperature = $0 }
                                    ),
                                    range: -1 ... 1,
                                    accessibilityValue: temperatureValueString
                                )
                            }
                            .disabled(activePreset.isLocked)

                            parameterSection("OVERLAY", accessibilityLabel: "Overlay section") {
                                HStack(spacing: 12) {
                                    Text("Color")
                                        .accessibilityHidden(true)
                                    Spacer()
                                    ColorPicker("", selection: overlayColorBinding, supportsOpacity: false)
                                        .labelsHidden()
                                        .focusable()
                                        .accessibilityLabel("Overlay color")
                                        .accessibilityValue(overlayColorAccessibilityValue)
                                        .accessibilityHint("Opens the color picker for the overlay tint.")
                                }

                                sliderRow(
                                    title: "Opacidad",
                                    accessibilityLabel: "Overlay opacity",
                                    value: Binding(
                                        get: { appState.liveParameters.overlayOpacity },
                                        set: { appState.liveParameters.overlayOpacity = $0 }
                                    ),
                                    range: 0 ... 0.6,
                                    accessibilityValue: percentageValueString
                                )
                            }
                            .disabled(activePreset.isLocked)
                        }
                        .padding(20)
                    }

                    Divider()
                        .accessibilityHidden(true)

                    HStack(spacing: 10) {
                        Button("Guardar") {
                            appState.saveActivePresetChanges()
                        }
                        .disabled(activePreset.isLocked || !appState.hasUnsavedChanges)
                        .focusable()
                        .accessibilityLabel("Save preset changes")
                        .accessibilityHint("Applies the current parameter edits to the selected preset.")

                        Button("Descartar") {
                            appState.discardActivePresetChanges()
                        }
                        .disabled(!appState.hasUnsavedChanges)
                        .focusable()
                        .accessibilityLabel("Discard preset changes")
                        .accessibilityHint("Restores the selected preset to its last saved values.")

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
                        .accessibilityHidden(true)
                    Text("Selecciona un preset")
                        .font(.headline)
                    Text("Elige un preset en la columna izquierda para editarlo.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .combine)
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
                guard let nsColor = NSColor(newColor).usingColorSpace(.extendedSRGB) else {
                    return
                }

                var hue: CGFloat = 0
                var saturation: CGFloat = 0
                var brightness: CGFloat = 0
                var alpha: CGFloat = 0

                nsColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
                let previousHue = appState.liveParameters.overlayHue
                appState.liveParameters.overlayHue = FilterParameters.resolvedOverlayHue(
                    from: Double(hue),
                    saturation: Double(saturation),
                    brightness: Double(brightness),
                    previousHue: previousHue
                )
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
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func parameterSection<Content: View>(
        _ title: String,
        accessibilityLabel: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityAddTraits(.isHeader)

            content()
        }
    }

    @ViewBuilder
    private func sliderRow(
        title: String,
        accessibilityLabel: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        accessibilityValue: @escaping (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .accessibilityHidden(true)
                Spacer()
                Text(visualValueString(for: value.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            Slider(value: value, in: range)
                .focusable()
                .accessibilityLabel(accessibilityLabel)
                .accessibilityValue(accessibilityValue(value.wrappedValue))
                .accessibilityHint("Use the left and right arrow keys to adjust the value.")
        }
    }

    private var overlayColorAccessibilityValue: String {
        "Hue \(percentageValueString(appState.liveParameters.overlayHue)), saturation \(percentageValueString(appState.liveParameters.overlaySaturation)), brightness \(percentageValueString(appState.liveParameters.overlayBrightness))"
    }

    private func visualValueString(for value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func percentageValueString(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func signedPercentageValueString(_ value: Double) -> String {
        let percentage = Int((abs(value) * 100).rounded())

        switch value {
        case let value where value > 0:
            return "Plus \(percentage) percent"
        case let value where value < 0:
            return "Minus \(percentage) percent"
        default:
            return "Zero percent"
        }
    }

    private func gammaValueString(_ value: Double) -> String {
        String(format: "%.2f times", value)
    }

    private func temperatureValueString(_ value: Double) -> String {
        let percentage = Int((abs(value) * 100).rounded())

        switch value {
        case let value where value > 0:
            return "Warm \(percentage) percent"
        case let value where value < 0:
            return "Cool \(percentage) percent"
        default:
            return "Neutral"
        }
    }
}
