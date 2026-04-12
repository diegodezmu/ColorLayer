import AppKit
import QuartzCore

final class OverlayView: NSView {
    private let dimmingLayer = CALayer()
    private let colorOverlayLayer = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayers()
        update(with: .neutral)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layer?.frame = bounds
        dimmingLayer.frame = bounds
        colorOverlayLayer.frame = bounds
    }

    func update(with parameters: FilterParameters) {
        dimmingLayer.backgroundColor = NSColor.black.cgColor
        dimmingLayer.opacity = Float(parameters.dimming)
        colorOverlayLayer.backgroundColor = NSColor(
            calibratedHue: parameters.overlayHue,
            saturation: parameters.overlaySaturation,
            brightness: parameters.overlayBrightness,
            alpha: 1.0
        ).cgColor
        colorOverlayLayer.opacity = Float(parameters.overlayOpacity)
    }

    private func setupLayers() {
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.clear.cgColor

        dimmingLayer.backgroundColor = NSColor.clear.cgColor
        colorOverlayLayer.backgroundColor = NSColor.clear.cgColor

        layer?.addSublayer(dimmingLayer)
        layer?.addSublayer(colorOverlayLayer)
    }
}
