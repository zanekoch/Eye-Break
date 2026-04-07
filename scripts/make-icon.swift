import AppKit
import Foundation

@MainActor
func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let background = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
    let gradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.06, green: 0.16, blue: 0.23, alpha: 1),
            NSColor(calibratedRed: 0.16, green: 0.39, blue: 0.49, alpha: 1)
        ]
    )!
    gradient.draw(in: background, angle: 90)

    let outerGlow = NSShadow()
    outerGlow.shadowColor = NSColor(calibratedWhite: 1, alpha: 0.18)
    outerGlow.shadowBlurRadius = size * 0.04
    outerGlow.shadowOffset = .zero
    outerGlow.set()

    let eyeRect = rect.insetBy(dx: size * 0.15, dy: size * 0.24)
    let eye = NSBezierPath()
    eye.move(to: NSPoint(x: eyeRect.minX, y: eyeRect.midY))
    eye.curve(
        to: NSPoint(x: eyeRect.midX, y: eyeRect.maxY),
        controlPoint1: NSPoint(x: eyeRect.minX + eyeRect.width * 0.16, y: eyeRect.maxY - eyeRect.height * 0.1),
        controlPoint2: NSPoint(x: eyeRect.midX - eyeRect.width * 0.18, y: eyeRect.maxY)
    )
    eye.curve(
        to: NSPoint(x: eyeRect.maxX, y: eyeRect.midY),
        controlPoint1: NSPoint(x: eyeRect.midX + eyeRect.width * 0.18, y: eyeRect.maxY),
        controlPoint2: NSPoint(x: eyeRect.maxX - eyeRect.width * 0.16, y: eyeRect.maxY - eyeRect.height * 0.1)
    )
    eye.curve(
        to: NSPoint(x: eyeRect.midX, y: eyeRect.minY),
        controlPoint1: NSPoint(x: eyeRect.maxX - eyeRect.width * 0.16, y: eyeRect.minY + eyeRect.height * 0.1),
        controlPoint2: NSPoint(x: eyeRect.midX + eyeRect.width * 0.18, y: eyeRect.minY)
    )
    eye.curve(
        to: NSPoint(x: eyeRect.minX, y: eyeRect.midY),
        controlPoint1: NSPoint(x: eyeRect.midX - eyeRect.width * 0.18, y: eyeRect.minY),
        controlPoint2: NSPoint(x: eyeRect.minX + eyeRect.width * 0.16, y: eyeRect.minY + eyeRect.height * 0.1)
    )
    eye.close()

    NSColor(calibratedWhite: 1.0, alpha: 0.96).setFill()
    eye.fill()

    let irisRect = NSRect(
        x: size * 0.31,
        y: size * 0.31,
        width: size * 0.38,
        height: size * 0.38
    )
    let iris = NSBezierPath(ovalIn: irisRect)
    let irisGradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.11, green: 0.41, blue: 0.48, alpha: 1),
            NSColor(calibratedRed: 0.04, green: 0.17, blue: 0.2, alpha: 1)
        ]
    )!
    irisGradient.draw(in: iris, relativeCenterPosition: .zero)

    let pupilRect = NSRect(
        x: size * 0.425,
        y: size * 0.425,
        width: size * 0.15,
        height: size * 0.15
    )
    NSColor(calibratedWhite: 0.05, alpha: 1).setFill()
    NSBezierPath(ovalIn: pupilRect).fill()

    NSColor(calibratedWhite: 1, alpha: 0.7).setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.38, y: size * 0.54, width: size * 0.07, height: size * 0.07)).fill()

    let lash = NSBezierPath()
    lash.move(to: NSPoint(x: size * 0.24, y: size * 0.53))
    lash.curve(
        to: NSPoint(x: size * 0.76, y: size * 0.53),
        controlPoint1: NSPoint(x: size * 0.35, y: size * 0.73),
        controlPoint2: NSPoint(x: size * 0.65, y: size * 0.73)
    )
    lash.lineWidth = max(2, size * 0.035)
    lash.lineCapStyle = .round
    NSColor(calibratedRed: 0.05, green: 0.17, blue: 0.2, alpha: 0.85).setStroke()
    lash.stroke()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiffData = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiffData),
        let pngData = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "EyeBreakIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG icon data."])
    }

    try pngData.write(to: url)
}

@MainActor
func main() throws {
    guard CommandLine.arguments.count == 2 else {
        throw NSError(domain: "EyeBreakIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Usage: swift make-icon.swift <iconset-dir>"])
    }

    let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    let fileManager = FileManager.default

    if fileManager.fileExists(atPath: iconsetURL.path) {
        try fileManager.removeItem(at: iconsetURL)
    }

    try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

    let icons: [(String, CGFloat)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]

    for (fileName, size) in icons {
        let image = drawIcon(size: size)
        try writePNG(image, to: iconsetURL.appendingPathComponent(fileName))
    }
}

Task { @MainActor in
    do {
        try main()
        exit(EXIT_SUCCESS)
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
        exit(EXIT_FAILURE)
    }
}

dispatchMain()
