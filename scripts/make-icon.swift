import AppKit
import CoreText

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
        NSColor.black.setFill()
        background.fill()
        let text: NSString = "ip"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 340, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text as String, attributes: attributes))
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        context.textPosition = CGPoint(x: 512 - bounds.midX, y: 512 - bounds.midY)
        CTLineDraw(line, context)
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
    }
}
