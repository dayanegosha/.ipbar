import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let background = NSBezierPath(roundedRect: NSRect(x: 74, y: 74, width: 876, height: 876), xRadius: 196, yRadius: 196)
        NSColor(calibratedRed: 0.1, green: 0.27, blue: 0.68, alpha: 1).setFill()
        background.fill()
        let gradient = NSGradient(starting: NSColor(calibratedRed: 0.28, green: 0.61, blue: 1, alpha: 1),
                                  ending: NSColor(calibratedRed: 0.10, green: 0.26, blue: 0.66, alpha: 1))!
        gradient.draw(in: background, angle: -90)
        let bar = NSBezierPath(roundedRect: NSRect(x: 186, y: 420, width: 652, height: 238), xRadius: 52, yRadius: 52)
        NSColor.white.setFill()
        bar.fill()
        let text: NSString = "IP"
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 142, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.12, green: 0.32, blue: 0.74, alpha: 1)]
        text.draw(at: NSPoint(x: 245, y: 447), withAttributes: attributes)
        NSColor(calibratedRed: 0.22, green: 0.65, blue: 0.4, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 673, y: 505, width: 68, height: 68)).fill()
        NSColor.white.withAlphaComponent(0.6).setFill()
        for x in [350, 486, 622] {
            NSBezierPath(roundedRect: NSRect(x: x, y: 303, width: 52, height: 18), xRadius: 9, yRadius: 9).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
    }
}
