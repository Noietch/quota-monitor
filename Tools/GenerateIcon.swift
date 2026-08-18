import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".build/AppIcon.iconset"
let sizes = [16, 32, 128, 256, 512]
let manager = FileManager.default
try manager.createDirectory(atPath: output, withIntermediateDirectories: true)

func render(size: Int, scale: Int, path: String) throws {
    let pixels = size * scale
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return }

    bitmap.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    let inset = CGFloat(size) * 0.06
    let backgroundRect = rect.insetBy(dx: inset, dy: inset)
    let background = NSBezierPath(roundedRect: backgroundRect, xRadius: CGFloat(size) * 0.22, yRadius: CGFloat(size) * 0.22)
    NSColor(calibratedWhite: 0.11, alpha: 1).setFill()
    background.fill()

    let center = NSPoint(x: CGFloat(size) / 2, y: CGFloat(size) / 2)
    let radius = CGFloat(size) * 0.29
    let track = NSBezierPath()
    track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
    track.lineWidth = CGFloat(size) * 0.075
    NSColor(calibratedWhite: 1, alpha: 0.18).setStroke()
    track.stroke()

    let progress = NSBezierPath()
    progress.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: -55, clockwise: true)
    progress.lineCapStyle = .round
    progress.lineWidth = CGFloat(size) * 0.075
    NSColor(calibratedRed: 0.20, green: 0.82, blue: 0.48, alpha: 1).setStroke()
    progress.stroke()

    let dotRadius = CGFloat(size) * 0.047
    let dotRect = NSRect(x: center.x - dotRadius, y: center.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
    NSColor.white.setFill()
    NSBezierPath(ovalIn: dotRect).fill()

    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
    try data.write(to: URL(fileURLWithPath: path))
}

for size in sizes {
    try render(size: size, scale: 1, path: "\(output)/icon_\(size)x\(size).png")
    try render(size: size, scale: 2, path: "\(output)/icon_\(size)x\(size)@2x.png")
}
