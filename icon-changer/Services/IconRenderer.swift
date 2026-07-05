//
//  IconRenderer.swift
//  icon-changer
//
//  Created by Paulo Ricardo Gomes Gois Silva on 04/07/26.
//

import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

final class IconRenderer {
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private let iconSize = CGSize(width: 1024, height: 1024)

    func normalizedIcon(from image: NSImage) -> NSImage {
        render(size: iconSize) { rect in
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        }
    }

    func darkVariant(
        from image: NSImage,
        background: NSColor,
        brightness: Double,
        contrast: Double,
        saturation: Double,
        scale: Double,
        invertColors: Bool
    ) -> NSImage {
        let normalized = normalizedIcon(from: image)
        let processed = process(
            normalized,
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            invertColors: invertColors
        )

        return render(size: iconSize) { rect in
            background.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 210, yRadius: 210).fill()

            let side = rect.width * scale
            let iconRect = CGRect(
                x: rect.midX - side / 2,
                y: rect.midY - side / 2,
                width: side,
                height: side
            )
            processed.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)
        }
    }

    private func process(
        _ image: NSImage,
        brightness: Double,
        contrast: Double,
        saturation: Double,
        invertColors: Bool
    ) -> NSImage {
        guard var ciImage = CIImage(data: image.tiffRepresentation ?? Data()) else {
            return image
        }

        if invertColors {
            let invertFilter = CIFilter.colorInvert()
            invertFilter.inputImage = ciImage
            if let outputImage = invertFilter.outputImage {
                ciImage = outputImage
            }
        }

        let controlsFilter = CIFilter.colorControls()
        controlsFilter.inputImage = ciImage
        controlsFilter.brightness = Float(brightness)
        controlsFilter.contrast = Float(contrast)
        controlsFilter.saturation = Float(saturation)

        guard
            let outputImage = controlsFilter.outputImage,
            let cgImage = context.createCGImage(outputImage, from: outputImage.extent)
        else {
            return image
        }

        return NSImage(cgImage: cgImage, size: image.size)
    }

    private func render(size: CGSize, draw: (CGRect) -> Void) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(CGRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
    }
}
