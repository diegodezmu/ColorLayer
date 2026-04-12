#!/usr/bin/env swift

import AppKit
import Foundation

struct IconRenderer {
    let canvasSize = CGSize(width: 1024, height: 1024)
    let backgroundColor = NSColor(deviceRed: 36.0 / 255.0, green: 41.0 / 255.0, blue: 53.0 / 255.0, alpha: 1.0)
    let symbolColor = NSColor.white
    let marginRatio: CGFloat = 0.2

    func render(symbolName: String, outputURL: URL) throws {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(canvasSize.width),
            pixelsHigh: Int(canvasSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw RendererError.bitmapCreationFailed
        }

        let symbolSide = canvasSize.width * (1.0 - (marginRatio * 2.0))
        let configuration = NSImage.SymbolConfiguration(
            pointSize: symbolSide,
            weight: .semibold,
            scale: .large
        )

        guard
            let baseSymbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil),
            let configuredSymbol = baseSymbol.withSymbolConfiguration(configuration)
        else {
            throw RendererError.symbolNotFound(symbolName)
        }

        let tintedSymbol = tintSymbol(configuredSymbol)
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw RendererError.bitmapCreationFailed
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        defer { NSGraphicsContext.restoreGraphicsState() }

        backgroundColor.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: canvasSize)).fill()

        let destinationRect = CGRect(
            x: (canvasSize.width - symbolSide) / 2.0,
            y: (canvasSize.height - symbolSide) / 2.0,
            width: symbolSide,
            height: symbolSide
        )

        tintedSymbol.draw(in: destinationRect)

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw RendererError.pngEncodingFailed
        }

        try pngData.write(to: outputURL)
    }

    private func tintSymbol(_ symbol: NSImage) -> NSImage {
        let tinted = NSImage(size: symbol.size)

        tinted.lockFocus()
        defer { tinted.unlockFocus() }

        symbol.draw(in: CGRect(origin: .zero, size: symbol.size))
        symbolColor.setFill()
        CGRect(origin: .zero, size: symbol.size).fill(using: .sourceIn)

        return tinted
    }
}

enum RendererError: LocalizedError {
    case symbolNotFound(String)
    case bitmapCreationFailed
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case let .symbolNotFound(symbolName):
            return "Could not load SF Symbol '\(symbolName)'."
        case .bitmapCreationFailed:
            return "Could not create a bitmap context for the icon renderer."
        case .pngEncodingFailed:
            return "Could not encode the rendered icon as PNG."
        }
    }
}

let arguments = CommandLine.arguments
let symbolName = arguments.count > 1 ? arguments[1] : "lightspectrum.horizontal"
let outputPath = arguments.count > 2 ? arguments[2] : "ColorLayer/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png"
let outputURL = URL(fileURLWithPath: outputPath)

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true,
    attributes: nil
)

do {
    try IconRenderer().render(symbolName: symbolName, outputURL: outputURL)
} catch {
    fputs("render_app_icon.swift: \(error.localizedDescription)\n", stderr)
    exit(1)
}
