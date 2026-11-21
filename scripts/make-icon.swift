// Draws the app icon (macOS shape: rounded square with margin) into an .iconset folder.
// Usage: swift scripts/make-icon.swift <out.iconset>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func draw(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let body = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    let shape = NSBezierPath(roundedRect: body, xRadius: s * 0.18, yRadius: s * 0.18)

    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = s * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.01)
    shadow.set()
    NSGradient(starting: NSColor(white: 0.30, alpha: 1), ending: NSColor(white: 0.09, alpha: 1))!.draw(in: shape, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    // Lens: silver ring, dark glass, a soft highlight.
    let c = NSPoint(x: s / 2, y: s * 0.47)
    func circle(_ r: CGFloat) -> NSBezierPath { NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)) }
    NSGradient(starting: NSColor(white: 0.92, alpha: 1), ending: NSColor(white: 0.55, alpha: 1))!.draw(in: circle(s * 0.25), angle: -90)
    NSGradient(starting: NSColor(white: 0.20, alpha: 1), ending: NSColor(white: 0.02, alpha: 1))!.draw(in: circle(s * 0.215), angle: -90)
    NSGradient(colors: [NSColor(red: 0.18, green: 0.32, blue: 0.62, alpha: 1), NSColor(red: 0.04, green: 0.06, blue: 0.14, alpha: 1)])!
        .draw(in: circle(s * 0.15), relativeCenterPosition: NSPoint(x: -0.3, y: 0.35))
    NSColor.white.withAlphaComponent(0.55).setFill()
    NSBezierPath(ovalIn: NSRect(x: c.x - s * 0.08, y: c.y + s * 0.035, width: s * 0.05, height: s * 0.035)).fill()

    // Restore arrow arcing round the lens.
    // Runs anticlockwise from 135° round to 55°; the head sits at 55° pointing along the arc.
    let r = s * 0.30, end = 55 * CGFloat.pi / 180
    let arc = NSBezierPath()
    arc.appendArc(withCenter: c, radius: r, startAngle: 135, endAngle: 55 + 360 - 5)
    arc.lineWidth = s * 0.028
    arc.lineCapStyle = .round
    NSColor(red: 0.35, green: 0.68, blue: 1.0, alpha: 1).setStroke()
    arc.stroke()
    let p = NSPoint(x: c.x + r * cos(end), y: c.y + r * sin(end))
    let along = NSPoint(x: -sin(end), y: cos(end)), out = NSPoint(x: cos(end), y: sin(end))
    let len = s * 0.075, half = s * 0.045
    let head = NSBezierPath()
    head.move(to: NSPoint(x: p.x + along.x * len * 0.6, y: p.y + along.y * len * 0.6))
    head.line(to: NSPoint(x: p.x - along.x * len * 0.4 + out.x * half, y: p.y - along.y * len * 0.4 + out.y * half))
    head.line(to: NSPoint(x: p.x - along.x * len * 0.4 - out.x * half, y: p.y - along.y * len * 0.4 - out.y * half))
    head.close()
    NSColor(red: 0.35, green: 0.68, blue: 1.0, alpha: 1).setFill()
    head.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for pt in [16, 32, 128, 256, 512] {
    try draw(pt).write(to: out.appendingPathComponent("icon_\(pt)x\(pt).png"))
    try draw(pt * 2).write(to: out.appendingPathComponent("icon_\(pt)x\(pt)@2x.png"))
}
