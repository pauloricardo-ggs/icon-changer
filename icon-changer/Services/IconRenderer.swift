//
//  IconRenderer.swift
//  icon-changer
//
//  Created by Paulo Ricardo Gomes Gois Silva on 04/07/26.
//

import AppKit

final class IconRenderer {
    private let iconSize = CGSize(width: 512, height: 512)

    func normalizedIcon(from image: NSImage) -> NSImage {
        render(size: iconSize) { rect in
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        }
    }

    func darkVariant(
        from image: NSImage,
        background: NSColor?,
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
            if let background {
                background.setFill()
                NSBezierPath(roundedRect: rect, xRadius: 210, yRadius: 210).fill()
            }

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
        guard
            var rect = Optional(CGRect(origin: .zero, size: image.size)),
            let sourceImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        else {
            return image
        }

        let bitmap = NSBitmapImageRep(cgImage: sourceImage)
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh

        for y in 0..<height {
            for x in 0..<width {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }

                let alpha = color.alphaComponent
                guard alpha > 0.02 else { continue }

                let red = color.redComponent
                let green = color.greenComponent
                let blue = color.blueComponent

                let luminance = (red * 0.2126) + (green * 0.7152) + (blue * 0.0722)
                let colorSaturation = saturationValue(red: red, green: green, blue: blue)
                let backgroundWeight = smoothstep(edge0: 0.40, edge1: 0.82, value: luminance)
                    * (1.0 - smoothstep(edge0: 0.18, edge1: 0.58, value: colorSaturation))

                guard backgroundWeight > 0.01 else { continue }

                let adjusted = adjustedColor(
                    red: red,
                    green: green,
                    blue: blue,
                    brightness: brightness,
                    contrast: contrast,
                    saturation: saturation,
                    invertColors: invertColors
                )

                let outputColor = NSColor(
                    deviceRed: clamp(red + ((adjusted.red - red) * backgroundWeight)),
                    green: clamp(green + ((adjusted.green - green) * backgroundWeight)),
                    blue: clamp(blue + ((adjusted.blue - blue) * backgroundWeight)),
                    alpha: alpha
                )
                bitmap.setColor(outputColor, atX: x, y: y)
            }
        }

        let outputImage = NSImage(size: image.size)
        outputImage.addRepresentation(bitmap)
        return outputImage
    }

    private func adjustedColor(
        red: Double,
        green: Double,
        blue: Double,
        brightness: Double,
        contrast: Double,
        saturation: Double,
        invertColors: Bool
    ) -> (red: Double, green: Double, blue: Double) {
        var red = invertColors ? 1.0 - red : red
        var green = invertColors ? 1.0 - green : green
        var blue = invertColors ? 1.0 - blue : blue

        red = ((red - 0.5) * contrast) + 0.5 + brightness
        green = ((green - 0.5) * contrast) + 0.5 + brightness
        blue = ((blue - 0.5) * contrast) + 0.5 + brightness

        let luminance = (red * 0.2126) + (green * 0.7152) + (blue * 0.0722)
        red = luminance + ((red - luminance) * saturation)
        green = luminance + ((green - luminance) * saturation)
        blue = luminance + ((blue - luminance) * saturation)

        return (clamp(red), clamp(green), clamp(blue))
    }

    private func saturationValue(red: Double, green: Double, blue: Double) -> Double {
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        guard maximum > 0 else { return 0 }
        return (maximum - minimum) / maximum
    }

    private func smoothstep(edge0: Double, edge1: Double, value: Double) -> Double {
        let normalized = clamp((value - edge0) / (edge1 - edge0))
        return normalized * normalized * (3.0 - (2.0 * normalized))
    }

    private func clamp(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }

    private func render(size: CGSize, draw: (CGRect) -> Void) -> NSImage {
        guard
            let representation = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(size.width),
                pixelsHigh: Int(size.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ),
            let context = NSGraphicsContext(bitmapImageRep: representation)
        else {
            return NSImage(size: size)
        }

        representation.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        NSColor.clear.setFill()
        CGRect(origin: .zero, size: size).fill()
        draw(CGRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(representation)
        return image
    }
}
