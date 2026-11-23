// Draws the app icon into an .iconset folder: a pencil sketch of a retro mirrorless camera
// (centre viewfinder hump, top dials, leatherette, big lens) on paper, in the macOS icon shape.
// Usage: swift scripts/make-icon.swift <out.iconset>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

/// Same strokes at every size: a fixed-seed generator.
struct RNG {
    var state: UInt64
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(state >> 33) / CGFloat(UInt32.max >> 1)
    }
    mutating func range(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * next() }
}

func draw(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let small = px <= 64                     // fewer, bolder strokes where detail would turn to mush
    var rng = RNG(state: 0x5EED)
    func P(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x * s, y: y * s) }

    // Paper plate with the usual macOS margin and soft shadow.
    let plate = NSBezierPath(roundedRect: NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8), xRadius: s * 0.18, yRadius: s * 0.18)
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = s * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.01)
    shadow.set()
    NSGradient(starting: NSColor(red: 0.99, green: 0.975, blue: 0.94, alpha: 1),
               ending: NSColor(red: 0.94, green: 0.91, blue: 0.85, alpha: 1))!.draw(in: plate, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()
    plate.addClip()

    let ink = NSColor(red: 0.13, green: 0.13, blue: 0.16, alpha: 1)
    let weight = s * (small ? 0.022 : 0.010)
    let wobble = s * (small ? 0.0015 : 0.0035)
    let passes = small ? 1 : 2

    /// A wobbly pencil line that overshoots its ends a little, drawn `passes` times.
    func line(_ a: NSPoint, _ b: NSPoint, width: CGFloat = 1, overshoot: CGFloat = 0.012, alpha: CGFloat = 1) {
        let dx = b.x - a.x, dy = b.y - a.y, len = hypot(dx, dy)
        guard len > 0 else { return }
        let ux = dx / len, uy = dy / len, nx = -uy, ny = ux
        for pass in 0..<passes {
            let o1 = s * overshoot * rng.range(0.2, 1), o2 = s * overshoot * rng.range(0.2, 1)
            let shift = pass == 0 ? 0 : wobble * min(1, len / (s * 0.1)) * rng.range(-1, 1)
            let phase = rng.range(0, 6.28), freq = rng.range(1, 2.5)
            let path = NSBezierPath()
            let n = max(6, Int(len / (s * 0.02)))
            for i in 0...n {
                let t = CGFloat(i) / CGFloat(n)
                let d = -o1 + (len + o1 + o2) * t
                let off = shift + wobble * min(1, len / (s * 0.15)) * sin(phase + t * freq * 6.28)
                let p = NSPoint(x: a.x + ux * d + nx * off, y: a.y + uy * d + ny * off)
                i == 0 ? path.move(to: p) : path.line(to: p)
            }
            path.lineWidth = weight * width * (pass == 0 ? 1 : 0.6)
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            ink.withAlphaComponent(alpha * (pass == 0 ? 1 : 0.55)).setStroke()
            path.stroke()
        }
    }
    func lines(_ pts: [NSPoint], closed: Bool = false, width: CGFloat = 1) {
        let all = closed ? pts + [pts[0]] : pts
        for i in 0..<(all.count - 1) { line(all[i], all[i + 1], width: width) }
    }
    /// A hand-drawn circle: radius drifts and the stroke runs past its start.
    func circle(_ c: NSPoint, _ r: CGFloat, width: CGFloat = 1, alpha: CGFloat = 1) {
        for pass in 0..<passes {
            let start = rng.range(0, 6.28), sweep = 6.28 * rng.range(1.04, 1.12)
            let phase = rng.range(0, 6.28), drift = wobble * (pass == 0 ? 1 : 1.6)
            let path = NSBezierPath()
            let n = 72
            for i in 0...n {
                let t = CGFloat(i) / CGFloat(n), a = start + sweep * t
                let rr = r + drift * sin(phase + a * 2) + (pass == 0 ? 0 : wobble * 0.8)
                let p = NSPoint(x: c.x + rr * cos(a), y: c.y + rr * sin(a))
                i == 0 ? path.move(to: p) : path.line(to: p)
            }
            path.lineWidth = weight * width * (pass == 0 ? 1 : 0.6)
            path.lineCapStyle = .round
            ink.withAlphaComponent(alpha * (pass == 0 ? 1 : 0.55)).setStroke()
            path.stroke()
        }
    }
    /// A light watercolour wash, slightly off the lines as if laid down by hand.
    func wash(_ path: NSBezierPath, _ color: NSColor) {
        let t = NSAffineTransform()
        t.translateX(by: s * 0.008, yBy: -s * 0.006)
        let p = path.copy() as! NSBezierPath
        p.transform(using: t as AffineTransform)
        color.setFill()
        p.fill()
    }

    // Geometry (fractions of the icon).
    let L: CGFloat = 0.19, R: CGFloat = 0.81, B: CGFloat = 0.29, T: CGFloat = 0.61
    let lens = P(0.5, 0.435)

    // Washes first, under the ink.
    wash(NSBezierPath(roundedRect: NSRect(x: L * s, y: B * s, width: (R - L) * s, height: (T - B) * s), xRadius: s * 0.035, yRadius: s * 0.035),
         NSColor(white: 0.55, alpha: 0.16))
    let hump = NSBezierPath()
    hump.move(to: P(0.39, T)); hump.line(to: P(0.425, 0.71)); hump.line(to: P(0.575, 0.71)); hump.line(to: P(0.61, T)); hump.close()
    wash(hump, NSColor(white: 0.55, alpha: 0.16))
    wash(NSBezierPath(ovalIn: NSRect(x: lens.x - s * 0.15, y: lens.y - s * 0.15, width: s * 0.3, height: s * 0.3)),
         NSColor(white: 0.35, alpha: 0.18))
    wash(NSBezierPath(ovalIn: NSRect(x: lens.x - s * 0.085, y: lens.y - s * 0.085, width: s * 0.17, height: s * 0.17)),
         NSColor(red: 0.30, green: 0.50, blue: 0.80, alpha: 0.35))

    // Body: a rounded box, its corners drawn as short chamfers.
    let k: CGFloat = 0.03
    lines([P(L + k, B), P(R - k, B), P(R, B + k), P(R, T - k), P(R - k, T), P(L + k, T), P(L, T - k), P(L, B + k)], closed: true, width: 1.15)

    // Viewfinder hump, hot shoe, and the eyepiece's front window.
    lines([P(0.39, T), P(0.425, 0.71), P(0.575, 0.71), P(0.61, T)])
    lines([P(0.455, 0.71), P(0.455, 0.728), P(0.545, 0.728), P(0.545, 0.71)], width: 0.8)
    if !small { lines([P(0.46, 0.645), P(0.54, 0.645), P(0.54, 0.675), P(0.46, 0.675)], closed: true, width: 0.6) }

    // Top dials: ISO on the left; shutter speed, shutter button and exposure compensation on the right.
    func dial(_ x0: CGFloat, _ x1: CGFloat, _ top: CGFloat) {
        lines([P(x0, T), P(x0, top), P(x1, top), P(x1, T)])
        guard !small else { return }
        var x = x0 + 0.012
        while x < x1 - 0.006 { line(P(x, T + 0.006), P(x, top - 0.006), width: 0.45, overshoot: 0.002, alpha: 0.8); x += 0.013 }
    }
    dial(0.23, 0.35, 0.668)
    dial(0.635, 0.735, 0.668)
    dial(0.75, 0.795, 0.652)
    lines([P(0.67, 0.668), P(0.67, 0.684), P(0.70, 0.684), P(0.70, 0.668)], width: 0.8)   // shutter button

    // Leatherette band across the front, cross-hatched either side of the lens.
    let bandLow: CGFloat = 0.355, bandHigh: CGFloat = 0.545
    line(P(L, bandLow), P(R, bandLow), width: 0.7, overshoot: 0.004)
    line(P(L, bandHigh), P(R, bandHigh), width: 0.7, overshoot: 0.004)
    if !small {
        let gap: CGFloat = 0.022, clear: CGFloat = 0.168
        for dir in [CGFloat(1), -1] {
            var x = L - 0.2
            while x < R {
                // Hatch from (x, bandLow) rising at 45°, clipped to the band and kept off the lens.
                let a = NSPoint(x: x, y: bandLow), b = NSPoint(x: x + (bandHigh - bandLow) * dir, y: bandHigh)
                var p0 = a, p1 = b
                func clampX(_ p: inout NSPoint, toward q: NSPoint, at xEdge: CGFloat) {
                    let t = (xEdge - p.x) / (q.x - p.x); p = NSPoint(x: xEdge, y: p.y + (q.y - p.y) * t)
                }
                let lo = min(p0.x, p1.x), hi = max(p0.x, p1.x)
                for (edgeLo, edgeHi) in [(L + 0.008, 0.5 - clear), (0.5 + clear, R - 0.008)] where hi > edgeLo && lo < edgeHi {
                    p0 = a; p1 = b
                    if p0.x < edgeLo { clampX(&p0, toward: p1, at: edgeLo) } else if p0.x > edgeHi { clampX(&p0, toward: p1, at: edgeHi) }
                    if p1.x < edgeLo { clampX(&p1, toward: p0, at: edgeLo) } else if p1.x > edgeHi { clampX(&p1, toward: p0, at: edgeHi) }
                    line(P(p0.x, p0.y), P(p1.x, p1.y), width: 0.35, overshoot: 0, alpha: 0.5)
                }
                x += gap * (dir > 0 ? 1 : 1.6)
            }
        }
    }

    // Lens: barrel, focus ring ridges, glass, a highlight.
    circle(lens, s * 0.15, width: 1.15)
    circle(lens, s * 0.12)
    if !small {
        for i in 0..<36 {
            let a = CGFloat(i) / 36 * 6.28
            line(NSPoint(x: lens.x + s * 0.124 * cos(a), y: lens.y + s * 0.124 * sin(a)),
                 NSPoint(x: lens.x + s * 0.146 * cos(a), y: lens.y + s * 0.146 * sin(a)), width: 0.4, overshoot: 0, alpha: 0.7)
        }
    }
    circle(lens, s * 0.085, width: 0.9)
    if !small { circle(lens, s * 0.05, width: 0.5, alpha: 0.6) }
    let glint = NSBezierPath()
    glint.appendArc(withCenter: lens, radius: s * 0.062, startAngle: 105, endAngle: 160)
    glint.lineWidth = weight * (small ? 1 : 1.6)
    glint.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.9).setStroke()
    glint.stroke()

    // Strap lug on each side.
    lines([P(L, 0.565), P(L - 0.018, 0.565), P(L - 0.018, 0.59), P(L, 0.59)], width: 0.8)
    lines([P(R, 0.565), P(R + 0.018, 0.565), P(R + 0.018, 0.59), P(R, 0.59)], width: 0.8)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for pt in [16, 32, 128, 256, 512] {
    try draw(pt).write(to: out.appendingPathComponent("icon_\(pt)x\(pt).png"))
    try draw(pt * 2).write(to: out.appendingPathComponent("icon_\(pt)x\(pt)@2x.png"))
}
