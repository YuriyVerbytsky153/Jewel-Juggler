// Jewel Juggler art generator.
// Paints every bitmap the app uses (backgrounds, blocks, characters, items, tutorial
// illustrations, HUD parts) with CoreGraphics and writes them as image sets into an
// asset catalog folder. Deterministic: the same run always produces the same art.
//
// Usage: swift generate_assets.swift "<path>/Assets.xcassets/Generated" [preview-dir]

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputRoot = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./Generated")
let previewRoot: URL? = CommandLine.arguments.count > 2 ? URL(fileURLWithPath: CommandLine.arguments[2]) : nil
let fm = FileManager.default
try? fm.createDirectory(at: outputRoot, withIntermediateDirectories: true)
if let previewRoot { try? fm.createDirectory(at: previewRoot, withIntermediateDirectories: true) }
try! #"{"info":{"author":"xcode","version":1}}"#.write(to: outputRoot.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

// MARK: - Colour helpers

struct Col {
    var r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1
    init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    init(hex: UInt32, _ a: CGFloat = 1) {
        r = CGFloat((hex >> 16) & 0xFF) / 255; g = CGFloat((hex >> 8) & 0xFF) / 255; b = CGFloat(hex & 0xFF) / 255; self.a = a
    }
    var cg: CGColor { CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [r, g, b, a])! }
    func mix(_ o: Col, _ t: CGFloat) -> Col { Col(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t, a + (o.a - a) * t) }
    func alpha(_ v: CGFloat) -> Col { Col(r, g, b, v) }
    func lighter(_ t: CGFloat) -> Col { mix(.white, t) }
    func darker(_ t: CGFloat) -> Col { mix(Col(0.05, 0.06, 0.12), t) }
    static let white = Col(1, 1, 1)
    static let ink = Col(hex: 0x1B2340)
}

struct Rng {
    var s: UInt64
    mutating func next() -> CGFloat {
        s ^= s >> 12; s ^= s << 25; s ^= s >> 27
        return CGFloat(Double((s &* 2685821657736338717) >> 11) / Double(1 << 53))
    }
    mutating func r(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * next() }
}

// MARK: - Canvas (top-left origin)

var ctx: CGContext!
var canvasW: CGFloat = 0, canvasH: CGFloat = 0

func begin(_ w: Int, _ h: Int) {
    canvasW = CGFloat(w); canvasH = CGFloat(h)
    ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.interpolationQuality = .high
}

/// Writes the current canvas as `<name>.imageset` marked @3x so 3 px = 1 pt.
func finish(_ name: String) {
    let image = ctx.makeImage()!
    let dir = outputRoot.appendingPathComponent("\(name).imageset")
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("\(name).png")
    let dest = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil); CGImageDestinationFinalize(dest)
    let json = #"{"images":[{"idiom":"universal","scale":"1x"},{"idiom":"universal","scale":"2x"},{"filename":"\#(name).png","idiom":"universal","scale":"3x"}],"info":{"author":"xcode","version":1}}"#
    try! json.write(to: dir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    if let previewRoot { try? fm.removeItem(at: previewRoot.appendingPathComponent("\(name).png")); try? fm.copyItem(at: file, to: previewRoot.appendingPathComponent("\(name).png")) }
}

func gradient(_ cols: [Col], _ locs: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: cols.map(\.cg) as CFArray, locations: locs)!
}

func rr(_ r: CGRect, _ radius: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: min(radius, r.width / 2), cornerHeight: min(radius, r.height / 2), transform: nil) }
func ellipse(_ r: CGRect) -> CGPath { CGPath(ellipseIn: r, transform: nil) }
func circle(_ c: CGPoint, _ rad: CGFloat) -> CGPath { ellipse(CGRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2)) }
func poly(_ pts: [CGPoint]) -> CGPath { let p = CGMutablePath(); p.addLines(between: pts); p.closeSubpath(); return p }

func fill(_ path: CGPath, _ c: Col) { ctx.addPath(path); ctx.setFillColor(c.cg); ctx.fillPath() }
func stroke(_ path: CGPath, _ c: Col, _ w: CGFloat) { ctx.addPath(path); ctx.setStrokeColor(c.cg); ctx.setLineWidth(w); ctx.strokePath() }
func linearFill(_ path: CGPath, _ cols: [Col], _ from: CGPoint, _ to: CGPoint, _ locs: [CGFloat]? = nil) {
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    ctx.drawLinearGradient(gradient(cols, locs), start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}
func radialFill(_ path: CGPath, _ cols: [Col], _ c: CGPoint, _ radius: CGFloat, _ locs: [CGFloat]? = nil) {
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    ctx.drawRadialGradient(gradient(cols, locs), startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [.drawsAfterEndLocation])
    ctx.restoreGState()
}
func glow(_ c: CGPoint, _ radius: CGFloat, _ col: Col) {
    ctx.saveGState(); ctx.setBlendMode(.screen)
    ctx.drawRadialGradient(gradient([col, col.alpha(0)]), startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [])
    ctx.restoreGState()
}
func shadowed(_ offsetY: CGFloat, _ blur: CGFloat, _ col: Col = Col(0.05, 0.08, 0.2, 0.35), _ body: () -> Void) {
    ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: -offsetY), blur: blur, color: col.cg); ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    body()
    ctx.endTransparencyLayer(); ctx.restoreGState()
}
func text(_ s: String, _ p: CGPoint, size: CGFloat, weight: NSFont.Weight = .black, color: Col, center: Bool = true) {
    var font = NSFont.systemFont(ofSize: size, weight: weight)
    if let d = font.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: d, size: size) { font = f }
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(cgColor: color.cg)!]
    let str = NSAttributedString(string: s, attributes: attrs)
    let sz = str.size()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    str.draw(at: CGPoint(x: center ? p.x - sz.width / 2 : p.x, y: p.y - sz.height / 2))
    NSGraphicsContext.restoreGraphicsState()
}


/// Text in a named font (Copperplate for the engraved court look).
func fontText(_ s: String, _ p: CGPoint, font name: String, size: CGFloat, color: Col, stroke: Col? = nil, strokeWidth: CGFloat = 0, kern: CGFloat = 0) {
    let font = NSFont(name: name, size: size) ?? NSFont.boldSystemFont(ofSize: size)
    var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(cgColor: color.cg)!, .kern: kern]
    let measure = NSAttributedString(string: s, attributes: attrs).size()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    if let stroke {
        var sAttrs = attrs
        sAttrs[.strokeColor] = NSColor(cgColor: stroke.cg)!
        sAttrs[.strokeWidth] = strokeWidth
        NSAttributedString(string: s, attributes: sAttrs).draw(at: CGPoint(x: p.x - measure.width / 2, y: p.y - measure.height / 2))
    }
    attrs[.strokeWidth] = 0
    NSAttributedString(string: s, attributes: attrs).draw(at: CGPoint(x: p.x - measure.width / 2, y: p.y - measure.height / 2))
    NSGraphicsContext.restoreGraphicsState()
}

// MARK: - Court palette

enum P {
    static let velvetDeep = Col(hex: 0x120F2B)
    static let velvet = Col(hex: 0x241F55)
    static let velvetLight = Col(hex: 0x3D3680)
    static let teal = Col(hex: 0x1C8584)
    static let tealLight = Col(hex: 0x45C4B9)
    static let saffron = Col(hex: 0xF2B33D)
    static let gold = Col(hex: 0xCC9A3D)
    static let goldLight = Col(hex: 0xF6D77E)
    static let goldDeep = Col(hex: 0x845C1F)
    static let ivory = Col(hex: 0xF7EDD6)
    static let parchment = Col(hex: 0xEEDCB5)
    static let parchmentDark = Col(hex: 0xC9AE7C)
    static let ink = Col(hex: 0x1F1733)
    static let rose = Col(hex: 0xCC2E45)
    static let candle = Col(hex: 0xFFDB8C)
    static let flame = Col(hex: 0xFFB347)
    static let wood = Col(hex: 0x7A4826)
    static let woodDark = Col(hex: 0x3E2312)
    static let skin = Col(hex: 0xF2C9A0)
    static let outline = Col(hex: 0x1A1230)
}

func gemColor(_ name: String) -> Col {
    switch name {
    case "ruby": return Col(hex: 0xDC2640)
    case "sapphire": return Col(hex: 0x2E6BEB)
    case "emerald": return Col(hex: 0x1FB26B)
    case "topaz": return Col(hex: 0xFAB829)
    default: return Col(hex: 0x9E5CE0)
    }
}

let gemNames = ["ruby", "sapphire", "emerald", "topaz", "amethyst"]

func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

func regularPolygon(_ c: CGPoint, _ r: CGFloat, sides: Int, rotation: CGFloat = 0, squashY: CGFloat = 1) -> [CGPoint] {
    (0..<sides).map { i in
        let a = rotation + CGFloat(i) / CGFloat(sides) * .pi * 2 - .pi / 2
        return pt(c.x + cos(a) * r, c.y + sin(a) * r * squashY)
    }
}

func starPath(_ c: CGPoint, _ outer: CGFloat, _ inner: CGFloat, points: Int = 4, rotation: CGFloat = 0) -> CGPath {
    var pts: [CGPoint] = []
    for i in 0..<(points * 2) {
        let r = i % 2 == 0 ? outer : inner
        let a = rotation + CGFloat(i) / CGFloat(points * 2) * .pi * 2 - .pi / 2
        pts.append(pt(c.x + cos(a) * r, c.y + sin(a) * r))
    }
    return poly(pts)
}

func line(_ a: CGPoint, _ b: CGPoint, _ c: Col, _ w: CGFloat) {
    let p = CGMutablePath(); p.move(to: a); p.addLine(to: b); stroke(p, c, w)
}

/// A faceted cut gem: outer outline, inner table and shaded facets lit from the top-left.
func drawFacetedGem(outer: [CGPoint], tableScale: CGFloat = 0.52, base: Col, outlineWidth: CGFloat) {
    let cx = outer.map(\.x).reduce(0, +) / CGFloat(outer.count)
    let cy = outer.map(\.y).reduce(0, +) / CGFloat(outer.count)
    let tableCenter = pt(cx - (outer.map(\.x).max()! - cx) * 0.06, cy - (outer.map(\.y).max()! - cy) * 0.08)
    let inner = outer.map { pt(tableCenter.x + ($0.x - cx) * tableScale, tableCenter.y + ($0.y - cy) * tableScale) }
    let light = CGPoint(x: -0.6, y: -0.8)
    shadowed(outlineWidth * 0.8, outlineWidth * 2, Col(0, 0, 0.05, 0.35)) {
        fill(poly(outer), base.darker(0.35))
    }
    for i in 0..<outer.count {
        let j = (i + 1) % outer.count
        let a = outer[i], b = outer[j]
        let mid = pt((a.x + b.x) / 2 - cx, (a.y + b.y) / 2 - cy)
        let len = max(0.001, hypot(mid.x, mid.y))
        let dot = (mid.x * light.x + mid.y * light.y) / len
        let shade = dot > 0 ? base.lighter(0.12 + dot * 0.45) : base.darker(-dot * 0.42)
        fill(poly([a, b, inner[j], inner[i]]), shade)
        // A secondary split per facet for sparkle.
        let m = pt((a.x + b.x) / 2, (a.y + b.y) / 2)
        let mi = pt((inner[i].x + inner[j].x) / 2, (inner[i].y + inner[j].y) / 2)
        fill(poly([a, m, mi, inner[i]]), shade.lighter(0.08))
    }
    linearFill(poly(inner), [base.lighter(0.55), base.lighter(0.15), base], pt(tableCenter.x - 40, tableCenter.y - 40), pt(tableCenter.x + 40, tableCenter.y + 40))
    for i in 0..<outer.count { line(outer[i], inner[i], base.lighter(0.5).alpha(0.55), outlineWidth * 0.35) }
    stroke(poly(inner), base.lighter(0.6).alpha(0.7), outlineWidth * 0.35)
    stroke(poly(outer), base.darker(0.6), outlineWidth)
    // Glint.
    let gx = inner[0].x * 0.5 + inner[inner.count - 1].x * 0.5
    let gy = inner[0].y * 0.5 + inner[inner.count - 1].y * 0.5
    fill(starPath(pt(gx + (tableCenter.x - gx) * 0.25, gy + (tableCenter.y - gy) * 0.25), outlineWidth * 3.2, outlineWidth * 0.6), Col.white.alpha(0.95))
}

/// Gem outline per colour, so colours also differ by shape.
func gemOutline(_ name: String, _ r: CGRect) -> [CGPoint] {
    let c = pt(r.midX, r.midY)
    let s = r.width / 2
    switch name {
    case "ruby": return regularPolygon(c, s, sides: 8, rotation: .pi / 8)
    case "sapphire":
        let i = s * 0.32
        return [pt(c.x - s + i, c.y - s * 0.92), pt(c.x + s - i, c.y - s * 0.92), pt(c.x + s, c.y - s * 0.92 + i), pt(c.x + s, c.y + s * 0.92 - i),
                pt(c.x + s - i, c.y + s * 0.92), pt(c.x - s + i, c.y + s * 0.92), pt(c.x - s, c.y + s * 0.92 - i), pt(c.x - s, c.y - s * 0.92 + i)]
    case "emerald":
        let w = s * 0.78, h = s, i = s * 0.26
        return [pt(c.x - w + i, c.y - h), pt(c.x + w - i, c.y - h), pt(c.x + w, c.y - h + i), pt(c.x + w, c.y + h - i),
                pt(c.x + w - i, c.y + h), pt(c.x - w + i, c.y + h), pt(c.x - w, c.y + h - i), pt(c.x - w, c.y - h + i)]
    case "topaz":
        // Pear: rounded bottom, pointed top.
        var pts: [CGPoint] = [pt(c.x, c.y - s)]
        for k in 0...8 {
            let a = -CGFloat.pi * 0.05 + CGFloat(k) / 8 * CGFloat.pi * 1.1
            pts.append(pt(c.x + cos(a) * s * 0.78, c.y + s * 0.22 + sin(a) * s * 0.74))
        }
        return pts
    default: return regularPolygon(c, s, sides: 6, rotation: 0)
    }
}

func drawGem(_ name: String, _ r: CGRect) {
    drawFacetedGem(outer: gemOutline(name, r), base: gemColor(name), outlineWidth: r.width * 0.035)
}

/// A small gilded crown.
func drawCrown(_ r: CGRect) {
    let p = CGMutablePath()
    p.move(to: pt(r.minX, r.maxY))
    p.addLine(to: pt(r.minX, r.minY + r.height * 0.35))
    p.addLine(to: pt(r.minX + r.width * 0.25, r.minY + r.height * 0.62))
    p.addLine(to: pt(r.midX, r.minY))
    p.addLine(to: pt(r.maxX - r.width * 0.25, r.minY + r.height * 0.62))
    p.addLine(to: pt(r.maxX, r.minY + r.height * 0.35))
    p.addLine(to: pt(r.maxX, r.maxY))
    p.closeSubpath()
    shadowed(r.height * 0.05, r.height * 0.1) {
        linearFill(p, [P.goldLight, P.saffron, P.goldDeep], pt(0, r.minY), pt(0, r.maxY))
    }
    stroke(p, P.goldDeep.darker(0.3), r.width * 0.05)
    for x in [r.minX, r.midX, r.maxX] {
        let y = x == r.midX ? r.minY : r.minY + r.height * 0.35
        fill(circle(pt(x, y), r.width * 0.07), P.ivory)
    }
    fill(rr(CGRect(x: r.minX, y: r.maxY - r.height * 0.22, width: r.width, height: r.height * 0.22), r.height * 0.05), P.goldDeep)
}

/// Harlequin diamond pattern clipped to a path.
func harlequin(_ path: CGPath, _ a: Col, _ b: Col, cell: CGFloat, bounds: CGRect, angle: CGFloat = 0) {
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    fill(CGPath(rect: bounds.insetBy(dx: -cell * 2, dy: -cell * 2), transform: nil), a)
    let w = cell, h = cell * 1.5
    var row = 0
    var y = bounds.minY - h
    while y < bounds.maxY + h {
        var x = bounds.minX - w + (row % 2 == 0 ? 0 : w / 2)
        while x < bounds.maxX + w {
            // Rotated checkerboard: alternate rows take the second colour.
            if row % 2 == 1 { fill(poly([pt(x + w / 2, y), pt(x + w, y + h / 2), pt(x + w / 2, y + h), pt(x, y + h / 2)]), b) }
            x += w
        }
        y += h / 2
        row += 1
    }
    ctx.restoreGState()
}

/// A candle with flame and halo.
func drawCandle(_ base: CGPoint, height: CGFloat, width: CGFloat, glowStrength: CGFloat = 1) {
    let body = CGRect(x: base.x - width / 2, y: base.y - height, width: width, height: height)
    linearFill(rr(body, width * 0.2), [P.ivory, P.parchment, P.parchmentDark], pt(body.minX, 0), pt(body.maxX, 0))
    // Wax drip.
    fill(rr(CGRect(x: body.minX + width * 0.1, y: body.minY, width: width * 0.3, height: height * 0.25), width * 0.15), P.ivory)
    let flameTop = pt(base.x, body.minY - width * 2.1)
    glow(pt(base.x, body.minY - width * 0.9), width * 7 * glowStrength, P.candle.alpha(0.45 * glowStrength))
    let f = CGMutablePath()
    f.move(to: flameTop)
    f.addQuadCurve(to: pt(base.x, body.minY - width * 0.1), control: pt(base.x + width * 0.95, body.minY - width * 0.6))
    f.addQuadCurve(to: flameTop, control: pt(base.x - width * 0.95, body.minY - width * 0.6))
    fill(f, P.flame.alpha(min(1, 0.4 + glowStrength)))
    fill(ellipse(CGRect(x: base.x - width * 0.22, y: body.minY - width * 1.0, width: width * 0.44, height: width * 0.8)), Col(1, 0.97, 0.85, min(1, 0.5 + glowStrength)))
}

/// Writes the canvas also to an arbitrary file (icons).
func writePNG(_ url: URL) {
    let image = ctx.makeImage()!
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil); CGImageDestinationFinalize(dest)
}

// MARK: - Gems, crowns, joker, tomato, cracks

for name in gemNames {
    begin(180, 180)
    drawGem(name, CGRect(x: 16, y: 16, width: 148, height: 148))
    finish("gem_\(name)")

    begin(216, 216)
    glow(pt(108, 126), 104, P.goldLight.alpha(0.45))
    drawGem(name, CGRect(x: 30, y: 52, width: 156, height: 156))
    drawCrown(CGRect(x: 70, y: 8, width: 76, height: 52))
    // Gold rim around the crown gem.
    stroke(poly(gemOutline(name, CGRect(x: 26, y: 48, width: 164, height: 164))), P.saffron.alpha(0.9), 5)
    finish("crown_\(name)")
}

// Joker: a harlequin diamond in four colours.
func drawJokerShape() {
    let c = pt(90, 90)
    let top = pt(90, 10), right = pt(166, 90), bottom = pt(90, 170), left = pt(14, 90)
    shadowed(4, 8, Col(0, 0, 0.05, 0.35)) { fill(poly([top, right, bottom, left]), P.ink) }
    let quads: [([CGPoint], Col)] = [
        ([top, pt(128, 50), c, pt(52, 50)], P.saffron),
        ([right, pt(128, 130), c, pt(128, 50)], P.teal),
        ([bottom, pt(52, 130), c, pt(128, 130)], P.rose),
        ([left, pt(52, 50), c, pt(52, 130)], P.ivory),
    ]
    let corners = [top, right, bottom, left]
    for (index, (pts, col)) in quads.enumerated() {
        _ = index
        fill(poly([corners[index], pts[1], c]), col.lighter(0.25))
        fill(poly([corners[index], c, pts[3]]), col.darker(0.15))
    }
    _ = quads
    fill(poly([pt(90, 52), pt(128, 90), pt(90, 128), pt(52, 90)]), P.ivory.alpha(0.25))
    stroke(poly([pt(90, 52), pt(128, 90), pt(90, 128), pt(52, 90)]), P.goldLight, 4)
    stroke(poly([top, right, bottom, left]), P.goldDeep, 6)
    fill(starPath(pt(72, 60), 14, 3), Col.white.alpha(0.95))
    // Tiny bell in the centre.
    fill(circle(pt(90, 92), 12), P.goldLight)
    stroke(circle(pt(90, 92), 12), P.goldDeep, 3)
    fill(circle(pt(90, 97), 3.5), P.goldDeep)
}
begin(180, 180); drawJokerShape(); finish("gem_joker")

begin(180, 180)
do {
    let body = ellipse(CGRect(x: 18, y: 34, width: 144, height: 128))
    shadowed(4, 8, Col(0, 0, 0, 0.35)) { radialFill(body, [Col(hex: 0xF0593E), Col(hex: 0xC2321F), Col(hex: 0x7E1A10)], pt(66, 70), 130) }
    stroke(body, Col(hex: 0x5A120A), 5)
    // Bruised, overripe spots.
    fill(ellipse(CGRect(x: 104, y: 110, width: 30, height: 20)), Col(hex: 0x6B2A10, 0.6))
    fill(ellipse(CGRect(x: 48, y: 124, width: 18, height: 12)), Col(hex: 0x6B2A10, 0.5))
    fill(ellipse(CGRect(x: 46, y: 58, width: 34, height: 20)), Col.white.alpha(0.35))
    let leaf = CGMutablePath()
    for i in 0..<5 {
        let a = CGFloat(i) / 5 * .pi * 2 - .pi / 2
        leaf.move(to: pt(90, 40))
        leaf.addQuadCurve(to: pt(90 + cos(a) * 34, 40 + sin(a) * 14), control: pt(90 + cos(a + 0.4) * 22, 40 + sin(a + 0.4) * 16))
    }
    stroke(leaf, Col(hex: 0x3E7A2C), 9)
    stroke(leaf, Col(hex: 0x6DB84A), 4)
    line(pt(90, 40), pt(96, 18), Col(hex: 0x3E7A2C), 7)
}
finish("tomato")

// Cracks: thin pale lines, deeper with each stage; the last one glows red.
func drawCrackOverlay(_ stage: Int, _ rect: CGRect) {
    ctx.saveGState(); ctx.translateBy(x: rect.minX, y: rect.minY); ctx.scaleBy(x: rect.width / 180, y: rect.height / 180)
    var g = Rng(s: 77 + UInt64(stage))
    let branches = stage == 1 ? 2 : stage == 2 ? 4 : 6
    for b in 0..<branches {
        let p = CGMutablePath()
        var cur = pt(90 + g.r(-14, 14), 90 + g.r(-14, 14))
        p.move(to: cur)
        let dir = CGFloat(b) / CGFloat(branches) * .pi * 2 + g.r(-0.4, 0.4)
        for _ in 0..<(3 + stage) {
            let a = dir + g.r(-0.6, 0.6)
            cur = pt(cur.x + cos(a) * g.r(9, 15), cur.y + sin(a) * g.r(9, 15))
            p.addLine(to: cur)
        }
        if stage == 3 {
            ctx.saveGState(); ctx.setShadow(offset: .zero, blur: 10, color: Col(1, 0.3, 0.15, 1).cg)
            stroke(p, Col(1, 0.42, 0.2), 6); ctx.restoreGState()
            stroke(p, Col(1, 0.9, 0.7), 2.5)
        } else {
            stroke(p, Col(0.05, 0.03, 0.1, 0.55), 5)
            stroke(p, Col(1, 1, 1, 0.85), 2.2)
        }
    }
    ctx.restoreGState()
}

for stage in 1...3 {
    begin(180, 180)
    drawCrackOverlay(stage, CGRect(x: 0, y: 0, width: 180, height: 180))
    finish("crack_\(stage)")
}

// MARK: - Jesters (300 x 480 px, hands raised at the top)

enum Pattern { case diamond, stripes, split }
enum Motif { case none, moon, star, flame, wave, trim }

struct Look {
    let a: Col, b: Col, glove: Col, pattern: Pattern, motif: Motif
}

let looks: [(String, Look)] = [
    ("motley", Look(a: P.teal, b: P.saffron, glove: P.ivory, pattern: .diamond, motif: .none)),
    ("moonlitFool", Look(a: Col(hex: 0x2B2F73), b: Col(hex: 0xA9B4DE), glove: Col(hex: 0xDCE3F7), pattern: .split, motif: .moon)),
    ("saffronSprite", Look(a: P.saffron, b: P.ivory, glove: Col(hex: 0xF3E0A6), pattern: .stripes, motif: .none)),
    ("tidewaterMime", Look(a: Col(hex: 0x2B6CA6), b: Col(hex: 0xE9F2F7), glove: Col.white, pattern: .stripes, motif: .wave)),
    ("emberHarlequin", Look(a: Col(hex: 0xD9622B), b: Col(hex: 0x6E1C24), glove: Col(hex: 0xF6C58E), pattern: .diamond, motif: .flame)),
    ("velvetHerald", Look(a: Col(hex: 0x5C2A72), b: P.gold, glove: P.ivory, pattern: .split, motif: .trim)),
    ("starlitJoker", Look(a: Col(hex: 0x1B2559), b: P.tealLight, glove: P.ivory, pattern: .diamond, motif: .star)),
]

func patternFill(_ path: CGPath, _ look: Look, bounds: CGRect, cell: CGFloat) {
    switch look.pattern {
    case .diamond:
        harlequin(path, look.a, look.b, cell: cell, bounds: bounds)
    case .stripes:
        ctx.saveGState(); ctx.addPath(path); ctx.clip()
        fill(CGPath(rect: bounds, transform: nil), look.a)
        var x = bounds.minX - bounds.height
        while x < bounds.maxX {
            fill(poly([pt(x, bounds.maxY), pt(x + cell * 0.5, bounds.maxY), pt(x + cell * 0.5 + bounds.height * 0.5, bounds.minY), pt(x + bounds.height * 0.5, bounds.minY)]), look.b)
            x += cell
        }
        ctx.restoreGState()
    case .split:
        ctx.saveGState(); ctx.addPath(path); ctx.clip()
        fill(CGPath(rect: CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width / 2, height: bounds.height), transform: nil), look.a)
        fill(CGPath(rect: CGRect(x: bounds.midX, y: bounds.minY, width: bounds.width / 2, height: bounds.height), transform: nil), look.b)
        ctx.restoreGState()
    }
    // Soft volume shading over the pattern.
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    ctx.drawLinearGradient(gradient([Col.white.alpha(0.18), Col.white.alpha(0), Col(0, 0, 0.1, 0.28)], [0, 0.45, 1]), start: pt(bounds.minX, bounds.minY), end: pt(bounds.maxX, bounds.maxY), options: [])
    ctx.restoreGState()
}

func bell(_ c: CGPoint, _ r: CGFloat) {
    fill(circle(c, r), P.goldLight)
    radialFill(circle(c, r), [P.goldLight, P.saffron, P.goldDeep], pt(c.x - r * 0.3, c.y - r * 0.3), r * 1.4)
    stroke(circle(c, r), P.outline, max(2, r * 0.22))
    line(pt(c.x - r * 0.5, c.y + r * 0.1), pt(c.x + r * 0.5, c.y + r * 0.1), P.goldDeep, max(1.5, r * 0.15))
    fill(circle(pt(c.x, c.y + r * 0.45), r * 0.22), P.outline)
}

/// Draws a jester in its 300 x 480 design space, transformed into `rect`.
func drawJester(_ look: Look, frame: Int, in rect: CGRect) {
    ctx.saveGState()
    ctx.translateBy(x: rect.minX, y: rect.minY)
    ctx.scaleBy(x: rect.width / 300, y: rect.height / 480)
    let o = P.outline
    let ow: CGFloat = 5

    // Legs: split tights.
    let legL = poly([pt(120, 330), pt(148, 330), pt(144, 446), pt(122, 446)])
    let legR = poly([pt(152, 330), pt(180, 330), pt(178, 446), pt(156, 446)])
    fill(legL, look.a); fill(legR, look.b)
    stroke(legL, o, ow); stroke(legR, o, ow)
    // Curly shoes.
    for (side, col) in [(-1.0, look.b), (1.0, look.a)] {
        let s = CGFloat(side)
        let heel = pt(150 + s * 17, 446)
        let shoe = CGMutablePath()
        shoe.move(to: pt(heel.x - s * 16, 440))
        shoe.addLine(to: pt(heel.x + s * 14, 440))
        shoe.addQuadCurve(to: pt(heel.x + s * 58, 428), control: pt(heel.x + s * 40, 446))
        shoe.addQuadCurve(to: pt(heel.x + s * 50, 466), control: pt(heel.x + s * 70, 450))
        shoe.addQuadCurve(to: pt(heel.x - s * 16, 468), control: pt(heel.x + s * 10, 474))
        shoe.closeSubpath()
        fill(shoe, col.darker(0.15)); stroke(shoe, o, ow)
        bell(pt(heel.x + s * 60, 424), 9)
    }

    // Arms (sleeves) raised in a V, hands at the top.
    let hands = frame == 0 ? [pt(64, 34), pt(236, 34)] : [pt(86, 54), pt(214, 54)]
    let elbows = frame == 0 ? [pt(70, 128), pt(230, 128)] : [pt(76, 140), pt(224, 140)]
    for (i, shoulder) in [pt(112, 214), pt(188, 214)].enumerated() {
        let arm = CGMutablePath()
        arm.move(to: shoulder)
        arm.addQuadCurve(to: hands[i], control: elbows[i])
        stroke(arm, o, 34)
        stroke(arm, i == 0 ? look.a : look.b, 24)
        // Cuff.
        let cuff = pt(hands[i].x + (shoulder.x - hands[i].x) * 0.16, hands[i].y + (shoulder.y - hands[i].y) * 0.16)
        fill(circle(cuff, 17), o)
        fill(circle(cuff, 13), i == 0 ? look.b : look.a)
        // Glove: palm open upwards.
        let g = CGMutablePath()
        g.addPath(circle(hands[i], 18))
        for f in 0..<3 {
            let fx = hands[i].x - 12 + CGFloat(f) * 12
            g.addPath(rr(CGRect(x: fx - 5, y: hands[i].y - 30, width: 10, height: 20), 5))
        }
        g.addPath(rr(CGRect(x: hands[i].x + (i == 0 ? 12 : -26), y: hands[i].y - 14, width: 14, height: 9), 4.5))
        stroke(g, o, 10)
        fill(g, look.glove)
    }

    // Tunic with zig-zag hem.
    let tunic = CGMutablePath()
    tunic.move(to: pt(104, 202))
    tunic.addLine(to: pt(196, 202))
    tunic.addLine(to: pt(214, 336))
    let points = 5
    for k in 0..<points {
        let x0 = 214 - CGFloat(k) * (128 / CGFloat(points))
        tunic.addLine(to: pt(x0 - 128 / CGFloat(points) / 2, 360))
        tunic.addLine(to: pt(x0 - 128 / CGFloat(points), 336))
    }
    tunic.closeSubpath()
    patternFill(tunic, look, bounds: CGRect(x: 80, y: 196, width: 140, height: 170), cell: 30)
    stroke(tunic, o, ow)
    for k in 0..<points {
        let x0 = 214 - CGFloat(k) * (128 / CGFloat(points))
        bell(pt(x0 - 128 / CGFloat(points) / 2, 364), 7)
    }
    // Belt.
    let belt = rr(CGRect(x: 100, y: 286, width: 104, height: 16), 6)
    fill(belt, P.goldDeep); stroke(belt, o, 4)
    fill(rr(CGRect(x: 141, y: 283, width: 20, height: 22), 4), P.goldLight); stroke(rr(CGRect(x: 141, y: 283, width: 20, height: 22), 4), o, 3)

    switch look.motif {
    case .moon:
        let m = CGMutablePath(); m.addPath(circle(pt(150, 246), 18))
        ctx.saveGState(); ctx.addPath(m); ctx.clip()
        fill(circle(pt(150, 246), 18), Col(hex: 0xF4F1DA))
        fill(circle(pt(160, 240), 16), look.a)
        ctx.restoreGState()
    case .star:
        for (x, y, r) in [(128.0, 232.0, 8.0), (172.0, 256.0, 7.0), (146.0, 316.0, 6.0), (190.0, 320.0, 5.0)] {
            fill(starPath(pt(x, y), r, r * 0.42, points: 5), P.goldLight)
        }
    case .flame:
        let f = CGMutablePath(); f.move(to: pt(150, 226)); f.addQuadCurve(to: pt(150, 272), control: pt(176, 252)); f.addQuadCurve(to: pt(150, 226), control: pt(126, 256))
        fill(f, P.saffron); stroke(f, o, 3)
    case .wave:
        let w = CGMutablePath(); w.move(to: pt(112, 262))
        for k in 0..<4 { w.addQuadCurve(to: pt(112 + CGFloat(k + 1) * 20, 262), control: pt(122 + CGFloat(k) * 20, 248)) }
        stroke(w, Col.white, 5)
    case .trim:
        line(pt(150, 204), pt(150, 286), P.goldLight, 6)
        for y in stride(from: 222.0, through: 270.0, by: 16) { fill(circle(pt(150, y), 4), P.ivory) }
    case .none:
        break
    }

    // Ruff collar.
    let ruff = CGMutablePath()
    for k in 0..<9 {
        let a = CGFloat(k) / 9 * .pi * 2
        ruff.addPath(circle(pt(150 + cos(a) * 46, 204 + sin(a) * 13), 15))
    }
    fill(ruff, P.ivory); stroke(ruff, o, 4)
    fill(ellipse(CGRect(x: 110, y: 194, width: 80, height: 22)), P.ivory)

    // Head.
    let head = circle(pt(150, 160), 40)
    radialFill(head, [P.skin.lighter(0.25), P.skin, P.skin.darker(0.18)], pt(138, 146), 60)
    stroke(head, o, ow)
    fill(circle(pt(124, 172), 9), P.rose.alpha(0.45))
    fill(circle(pt(176, 172), 9), P.rose.alpha(0.45))
    let eyeY: CGFloat = frame == 0 ? 156 : 152
    fill(ellipse(CGRect(x: 129, y: eyeY - 7, width: 10, height: 14)), o)
    fill(ellipse(CGRect(x: 161, y: eyeY - 7, width: 10, height: 14)), o)
    fill(circle(pt(136, eyeY - 3), 2.5), Col.white)
    fill(circle(pt(168, eyeY - 3), 2.5), Col.white)
    let smile = CGMutablePath(); smile.move(to: pt(132, 178)); smile.addQuadCurve(to: pt(168, 178), control: pt(150, frame == 0 ? 198 : 192))
    stroke(smile, o, 4.5)
    // Diamond face paint under one eye.
    fill(poly([pt(166, 166), pt(171, 174), pt(166, 182), pt(161, 174)]), look.a.darker(0.1))

    // Three-pointed cap.
    let band = rr(CGRect(x: 108, y: 120, width: 84, height: 22), 9)
    // Each horn: start, tip, two controls, end.
    let horns: [(CGPoint, CGPoint, CGPoint, CGPoint, CGPoint, Col)] = [
        (pt(100, 132), pt(46, 118), pt(70, 96), pt(70, 120), pt(126, 126), look.a),
        (pt(124, 126), pt(152, 56), pt(118, 84), pt(178, 86), pt(176, 126), look.b),
        (pt(200, 132), pt(254, 118), pt(230, 96), pt(230, 120), pt(174, 126), look.a),
    ]
    for (start, tip, c1, c2, end, col) in horns {
        let h = CGMutablePath()
        h.move(to: start)
        h.addQuadCurve(to: tip, control: c1)
        h.addQuadCurve(to: end, control: c2)
        h.closeSubpath()
        fill(h, col); stroke(h, o, ow)
        bell(tip, 11)
    }
    fill(band, look.b.darker(0.1)); stroke(band, o, ow)
    for k in 0..<4 { fill(poly([pt(118 + CGFloat(k) * 22, 131), pt(124 + CGFloat(k) * 22, 124), pt(130 + CGFloat(k) * 22, 131), pt(124 + CGFloat(k) * 22, 138)]), look.a) }
    ctx.restoreGState()
}

for (key, look) in looks {
    for frame in 0...1 {
        begin(300, 480)
        drawJester(look, frame: frame, in: CGRect(x: 0, y: 0, width: 300, height: 480))
        finish("jester_\(key)_\(frame)")
    }
}

// MARK: - Items and icons

func drawCoin(_ c: CGPoint, _ r: CGFloat) {
    shadowed(r * 0.06, r * 0.12) { fill(circle(c, r), P.goldDeep) }
    radialFill(circle(c, r * 0.94), [P.goldLight, P.saffron, P.gold], pt(c.x - r * 0.35, c.y - r * 0.4), r * 1.5)
    stroke(circle(c, r * 0.78), P.goldDeep, r * 0.06)
    stroke(circle(c, r), P.goldDeep.darker(0.3), r * 0.07)
    // A tiny jester cap emblem.
    let cap = CGMutablePath()
    cap.move(to: pt(c.x - r * 0.42, c.y + r * 0.2))
    cap.addQuadCurve(to: pt(c.x - r * 0.5, c.y - r * 0.32), control: pt(c.x - r * 0.25, c.y - r * 0.2))
    cap.addQuadCurve(to: pt(c.x, c.y - r * 0.5), control: pt(c.x - r * 0.12, c.y - r * 0.1))
    cap.addQuadCurve(to: pt(c.x + r * 0.5, c.y - r * 0.32), control: pt(c.x + r * 0.12, c.y - r * 0.1))
    cap.addQuadCurve(to: pt(c.x + r * 0.42, c.y + r * 0.2), control: pt(c.x + r * 0.25, c.y - r * 0.2))
    cap.closeSubpath()
    fill(cap, P.goldDeep)
    fill(rr(CGRect(x: c.x - r * 0.46, y: c.y + r * 0.16, width: r * 0.92, height: r * 0.22), r * 0.08), P.goldDeep)
    fill(starPath(pt(c.x - r * 0.42, c.y - r * 0.55), r * 0.22, r * 0.05), Col.white.alpha(0.9))
}

begin(120, 120); drawCoin(pt(60, 60), 52); finish("ducat")

func drawBellIcon(_ r: CGRect, lit: Bool) {
    let b = CGMutablePath()
    b.move(to: pt(r.midX, r.minY + r.height * 0.12))
    b.addCurve(to: pt(r.maxX - r.width * 0.1, r.maxY - r.height * 0.2), control1: pt(r.maxX - r.width * 0.18, r.minY + r.height * 0.12), control2: pt(r.maxX - r.width * 0.22, r.maxY - r.height * 0.34))
    b.addLine(to: pt(r.minX + r.width * 0.1, r.maxY - r.height * 0.2))
    b.addCurve(to: pt(r.midX, r.minY + r.height * 0.12), control1: pt(r.minX + r.width * 0.22, r.maxY - r.height * 0.34), control2: pt(r.minX + r.width * 0.18, r.minY + r.height * 0.12))
    b.closeSubpath()
    if lit {
        glow(pt(r.midX, r.midY), r.width * 0.6, P.candle.alpha(0.35))
        linearFill(b, [P.goldLight, P.saffron, P.goldDeep], pt(r.minX, r.minY), pt(r.maxX, r.maxY))
        stroke(b, P.outline, r.width * 0.06)
        fill(circle(pt(r.midX, r.maxY - r.height * 0.14), r.width * 0.1), P.goldDeep)
        stroke(circle(pt(r.midX, r.maxY - r.height * 0.14), r.width * 0.1), P.outline, r.width * 0.04)
        fill(ellipse(CGRect(x: r.minX + r.width * 0.3, y: r.minY + r.height * 0.28, width: r.width * 0.12, height: r.height * 0.28)), Col.white.alpha(0.6))
    } else {
        fill(b, P.velvet.alpha(0.8))
        ctx.setLineDash(phase: 0, lengths: [r.width * 0.08, r.width * 0.06])
        stroke(b, P.ivory.alpha(0.5), r.width * 0.05)
        ctx.setLineDash(phase: 0, lengths: [])
    }
    stroke(circle(pt(r.midX, r.minY + r.height * 0.08), r.width * 0.07), lit ? P.outline : P.ivory.alpha(0.5), r.width * 0.04)
}

begin(96, 96); drawBellIcon(CGRect(x: 8, y: 6, width: 80, height: 86), lit: true); finish("bell_on")
begin(96, 96); drawBellIcon(CGRect(x: 8, y: 6, width: 80, height: 86), lit: false); finish("bell_off")

/// A floppy three-horned cap on its own, with bells.
func drawCap(_ r: CGRect) {
    let s = r.width / 150
    ctx.saveGState(); ctx.translateBy(x: r.minX, y: r.minY); ctx.scaleBy(x: s, y: s)
    let horns: [(CGPoint, CGPoint, CGPoint, CGPoint, CGPoint, Col)] = [
        (pt(30, 108), pt(10, 60), pt(18, 90), pt(36, 62), pt(70, 104), P.teal),
        (pt(54, 104), pt(80, 16), pt(48, 52), pt(104, 46), pt(100, 104), P.saffron),
        (pt(84, 104), pt(140, 58), pt(118, 60), pt(130, 88), pt(122, 108), P.teal),
    ]
    for (start, tip, c1, c2, end, col) in horns {
        let h = CGMutablePath(); h.move(to: start); h.addQuadCurve(to: tip, control: c1); h.addQuadCurve(to: end, control: c2); h.closeSubpath()
        fill(h, col); stroke(h, P.outline, 5)
    }
    let band = rr(CGRect(x: 22, y: 100, width: 106, height: 26), 10)
    harlequin(band, P.velvet, P.saffron, cell: 18, bounds: CGRect(x: 22, y: 100, width: 106, height: 26))
    stroke(band, P.outline, 5)
    bell(pt(10, 60), 11); bell(pt(80, 16), 11); bell(pt(140, 58), 11)
    ctx.restoreGState()
}

begin(150, 150); drawCap(CGRect(x: 0, y: 6, width: 150, height: 150)); finish("cap_jingle")

func drawChest(_ r: CGRect, open: Bool) {
    let body = CGRect(x: r.minX, y: r.minY + r.height * 0.42, width: r.width, height: r.height * 0.58)
    if open {
        // Lid tipped back, warm glow and gems inside.
        let lid = CGMutablePath()
        lid.move(to: pt(body.minX + r.width * 0.04, body.minY))
        lid.addLine(to: pt(body.minX + r.width * 0.12, r.minY + r.height * 0.02))
        lid.addLine(to: pt(body.maxX - r.width * 0.12, r.minY + r.height * 0.02))
        lid.addLine(to: pt(body.maxX - r.width * 0.04, body.minY))
        lid.closeSubpath()
        linearFill(lid, [P.woodDark, P.wood], pt(0, r.minY), pt(0, body.minY))
        stroke(lid, P.outline, r.width * 0.025)
        glow(pt(r.midX, body.minY), r.width * 0.55, P.candle.alpha(0.8))
        fill(ellipse(CGRect(x: body.minX + r.width * 0.06, y: body.minY - r.height * 0.06, width: r.width * 0.88, height: r.height * 0.16)), P.woodDark)
        let gs = r.width * 0.2
        for (i, name) in ["ruby", "topaz", "sapphire", "emerald"].enumerated() {
            drawGem(name, CGRect(x: body.minX + r.width * 0.1 + CGFloat(i) * r.width * 0.19, y: body.minY - gs * 0.62 + (i % 2 == 0 ? 0 : -gs * 0.12), width: gs, height: gs))
        }
    }
    shadowed(r.height * 0.03, r.height * 0.06) {
        linearFill(rr(body, r.width * 0.06), [P.wood.lighter(0.15), P.wood, P.woodDark], pt(0, body.minY), pt(0, body.maxY))
    }
    for k in 1..<4 { line(pt(body.minX + 6, body.minY + body.height * CGFloat(k) / 4), pt(body.maxX - 6, body.minY + body.height * CGFloat(k) / 4), P.woodDark.alpha(0.7), r.width * 0.012) }
    for x in [body.minX + r.width * 0.16, body.maxX - r.width * 0.16 - r.width * 0.08] {
        fill(CGPath(rect: CGRect(x: x, y: body.minY, width: r.width * 0.08, height: body.height), transform: nil), P.gold)
        stroke(CGPath(rect: CGRect(x: x, y: body.minY, width: r.width * 0.08, height: body.height), transform: nil), P.goldDeep, r.width * 0.01)
    }
    stroke(rr(body, r.width * 0.06), P.outline, r.width * 0.025)
    if !open {
        let lid = CGMutablePath()
        lid.move(to: pt(body.minX, body.minY + 4))
        lid.addQuadCurve(to: pt(body.maxX, body.minY + 4), control: pt(r.midX, r.minY + r.height * 0.02))
        lid.closeSubpath()
        linearFill(lid, [P.wood.lighter(0.25), P.wood], pt(0, r.minY), pt(0, body.minY))
        stroke(lid, P.outline, r.width * 0.025)
        for x in [body.minX + r.width * 0.16, body.maxX - r.width * 0.24] {
            line(pt(x + r.width * 0.04, body.minY + 2), pt(x + r.width * 0.04, r.minY + r.height * 0.16), P.gold, r.width * 0.08)
        }
    }
    // Lock plate.
    let plate = rr(CGRect(x: r.midX - r.width * 0.08, y: body.minY - r.height * 0.02, width: r.width * 0.16, height: r.height * 0.2), r.width * 0.03)
    fill(plate, P.goldLight); stroke(plate, P.goldDeep, r.width * 0.015)
    fill(circle(pt(r.midX, body.minY + r.height * 0.07), r.width * 0.02), P.outline)
}

begin(240, 210); drawChest(CGRect(x: 10, y: 10, width: 220, height: 190), open: false); finish("chest_closed")
begin(240, 210); drawChest(CGRect(x: 10, y: 10, width: 220, height: 190), open: true); finish("chest_open")

func drawRose(_ c: CGPoint, _ r: CGFloat, lit: Bool) {
    if !lit {
        // An empty rose: a dashed ivory outline so it never reads as earned.
        let petals = CGMutablePath()
        for p in regularPolygon(pt(c.x, c.y - r * 0.05), r * 0.62, sides: 5) { petals.addPath(circle(p, r * 0.34)) }
        ctx.setLineDash(phase: 0, lengths: [r * 0.12, r * 0.08])
        stroke(petals, P.ivory.alpha(0.75), r * 0.07)
        ctx.setLineDash(phase: 0, lengths: [])
        fill(circle(pt(c.x, c.y - r * 0.05), r * 0.2), P.ivory.alpha(0.35))
        return
    }
    let red = lit ? P.rose : P.velvetLight.alpha(0.55)
    let leaf = CGMutablePath()
    leaf.move(to: pt(c.x - r * 0.2, c.y + r * 0.55))
    leaf.addQuadCurve(to: pt(c.x - r * 0.95, c.y + r * 0.7), control: pt(c.x - r * 0.6, c.y + r * 0.25))
    leaf.addQuadCurve(to: pt(c.x - r * 0.2, c.y + r * 0.55), control: pt(c.x - r * 0.6, c.y + r * 1.05))
    leaf.move(to: pt(c.x + r * 0.2, c.y + r * 0.55))
    leaf.addQuadCurve(to: pt(c.x + r * 0.95, c.y + r * 0.7), control: pt(c.x + r * 0.6, c.y + r * 0.25))
    leaf.addQuadCurve(to: pt(c.x + r * 0.2, c.y + r * 0.55), control: pt(c.x + r * 0.6, c.y + r * 1.05))
    fill(leaf, lit ? Col(hex: 0x2F7A3E) : P.velvetLight.alpha(0.4))
    if lit { stroke(leaf, P.outline, r * 0.07) }
    for (k, rad) in [(0, 0.78), (1, 0.6), (2, 0.4), (3, 0.22)] {
        let shade = red.mix(k % 2 == 0 ? red.darker(0.3) : red.lighter(0.25), 0.5)
        let petals = regularPolygon(pt(c.x, c.y - r * 0.05), r * CGFloat(rad), sides: 5, rotation: CGFloat(k) * 0.6)
        let path = CGMutablePath()
        for p in petals { path.addPath(circle(p, r * CGFloat(rad) * 0.55)) }
        path.addPath(circle(pt(c.x, c.y - r * 0.05), r * CGFloat(rad) * 0.9))
        fill(path, shade)
    }
    if lit {
        stroke(circle(pt(c.x, c.y - r * 0.05), r * 0.95), P.outline.alpha(0.0), 1)
        fill(circle(pt(c.x - r * 0.25, c.y - r * 0.35), r * 0.12), Col.white.alpha(0.35))
    } else {
        stroke(circle(pt(c.x, c.y - r * 0.05), r * 0.82), P.ivory.alpha(0.35), r * 0.06)
    }
}

begin(120, 120); drawRose(pt(60, 56), 50, lit: true); finish("rose")
begin(120, 120); drawRose(pt(60, 56), 50, lit: false); finish("rose_empty")

func drawTassel(_ r: CGRect, lit: Bool) {
    let col = lit ? P.saffron : Col(hex: 0x8C86C8, 0.75)
    line(pt(r.midX, r.minY), pt(r.midX, r.minY + r.height * 0.2), lit ? P.goldDeep : P.ivory.alpha(0.3), r.width * 0.12)
    fill(circle(pt(r.midX, r.minY + r.height * 0.26), r.width * 0.26), lit ? P.goldDeep : P.velvetLight)
    let t = CGMutablePath()
    t.move(to: pt(r.midX - r.width * 0.18, r.minY + r.height * 0.32))
    t.addLine(to: pt(r.midX + r.width * 0.18, r.minY + r.height * 0.32))
    t.addLine(to: pt(r.maxX - r.width * 0.08, r.maxY))
    t.addLine(to: pt(r.minX + r.width * 0.08, r.maxY))
    t.closeSubpath()
    fill(t, col)
    for k in 0..<5 {
        let x = r.minX + r.width * 0.16 + CGFloat(k) * r.width * 0.17
        line(pt(r.midX + (x - r.midX) * 0.4, r.minY + r.height * 0.38), pt(x, r.maxY - 2), lit ? P.goldDeep.alpha(0.7) : P.velvetDeep.alpha(0.5), r.width * 0.05)
    }
    stroke(t, lit ? P.outline : P.ivory.alpha(0.7), r.width * 0.06)
}

begin(60, 96); drawTassel(CGRect(x: 10, y: 4, width: 40, height: 88), lit: true); finish("tassel_on")
begin(60, 96); drawTassel(CGRect(x: 10, y: 4, width: 40, height: 88), lit: false); finish("tassel_off")

begin(120, 120)
do {
    let shackle = CGMutablePath()
    shackle.move(to: pt(36, 62)); shackle.addLine(to: pt(36, 42)); shackle.addArc(center: pt(60, 42), radius: 24, startAngle: .pi, endAngle: 0, clockwise: false); shackle.addLine(to: pt(84, 62))
    stroke(shackle, P.outline, 16); stroke(shackle, Col(hex: 0xB9BFD0), 9)
    let body = rr(CGRect(x: 24, y: 56, width: 72, height: 54), 12)
    linearFill(body, [P.goldLight, P.saffron, P.goldDeep], pt(0, 56), pt(0, 110))
    stroke(body, P.outline, 5)
    fill(circle(pt(60, 78), 8), P.outline)
    fill(rr(CGRect(x: 56, y: 80, width: 8, height: 18), 3), P.outline)
}
finish("lock")

// Audience: a row of silhouetted heads, dim and lit (raised arms, warm rim light).
for lit in [false, true] {
    begin(1200, 120)
    var g = Rng(s: 991)
    var x: CGFloat = -20
    var shapes: [(CGPoint, CGFloat, Bool)] = []
    while x < 1220 {
        let r = g.r(26, 36)
        shapes.append((pt(x, g.r(54, 70)), r, g.next() > 0.6))
        x += r * 1.35
    }
    for (c, r, hat) in shapes {
        let body = CGMutablePath()
        body.addPath(circle(c, r * 0.62))
        body.addPath(ellipse(CGRect(x: c.x - r * 1.05, y: c.y + r * 0.45, width: r * 2.1, height: r * 1.8)))
        if hat { body.addPath(poly([pt(c.x - r * 0.6, c.y - r * 0.35), pt(c.x, c.y - r * 1.25), pt(c.x + r * 0.6, c.y - r * 0.35)])) }
        if lit {
            // Raised arms cheering, warm rim light from the stage: a shifted gold copy behind the silhouette.
            let arm = CGMutablePath()
            arm.move(to: pt(c.x - r * 0.75, c.y + r * 0.7)); arm.addLine(to: pt(c.x - r * 1.05, c.y - r * 0.6))
            arm.move(to: pt(c.x + r * 0.75, c.y + r * 0.7)); arm.addLine(to: pt(c.x + r * 1.05, c.y - r * 0.6))
            ctx.saveGState(); ctx.translateBy(x: 0, y: -3)
            stroke(arm, P.saffron, r * 0.3 + 4); fill(body, P.saffron)
            ctx.restoreGState()
            stroke(arm, Col(hex: 0x2A1B3E), r * 0.3)
            fill(body, Col(hex: 0x2A1B3E))
        } else {
            ctx.saveGState(); ctx.translateBy(x: 0, y: -2)
            fill(body, P.velvetLight.alpha(0.7))
            ctx.restoreGState()
            fill(body, Col(hex: 0x0B0818))
        }
    }
    finish(lit ? "crowd_lit" : "crowd")
}

func drawRosette(_ c: CGPoint, _ r: CGFloat, earned: Bool) {
    let ribbonCol = earned ? P.rose : P.velvetLight
    for side in [-1.0, 1.0] {
        let s = CGFloat(side)
        let tail = poly([pt(c.x + s * r * 0.15, c.y + r * 0.3), pt(c.x + s * r * 0.55, c.y + r * 1.05), pt(c.x + s * r * 0.38, c.y + r * 0.9), pt(c.x + s * r * 0.25, c.y + r * 1.1), pt(c.x - s * r * 0.05, c.y + r * 0.35)])
        fill(tail, ribbonCol.darker(0.15)); stroke(tail, P.outline.alpha(earned ? 1 : 0.4), r * 0.05)
    }
    let petals = CGMutablePath()
    for p in regularPolygon(c, r * 0.62, sides: 12) { petals.addPath(circle(p, r * 0.24)) }
    petals.addPath(circle(c, r * 0.65))
    fill(petals, earned ? P.teal : P.velvet)
    stroke(petals, P.outline.alpha(earned ? 1 : 0.4), r * 0.05)
    if earned { drawCoin(c, r * 0.42) } else {
        fill(circle(c, r * 0.42), P.velvetDeep)
        stroke(circle(c, r * 0.42), P.ivory.alpha(0.35), r * 0.04)
        fontText("?", pt(c.x, c.y), font: "Copperplate-Bold", size: r * 0.5, color: P.ivory.alpha(0.5))
    }
}

begin(180, 180); drawRosette(pt(90, 74), 66, earned: true); finish("rosette_earned")
begin(180, 180); drawRosette(pt(90, 74), 66, earned: false); finish("rosette_locked")

begin(600, 90)
do {
    let rod = rr(CGRect(x: 40, y: 34, width: 520, height: 20), 10)
    linearFill(rod, [P.goldLight, P.saffron, P.goldDeep], pt(0, 34), pt(0, 54))
    stroke(rod, P.outline, 3)
    for x in [CGFloat(26), 574] {
        fill(circle(pt(x, 44), 22), P.goldDeep)
        radialFill(circle(pt(x, 44), 20), [P.goldLight, P.saffron, P.goldDeep], pt(x - 6, 38), 30)
        stroke(circle(pt(x, 44), 20), P.outline, 3)
    }
}
finish("rack_rod")

// MARK: Props (240 x 240)

func propCanvas(_ name: String, _ body: () -> Void) {
    begin(240, 240)
    glow(pt(120, 120), 96, P.candle.alpha(0.22))
    body()
    finish(name)
}

propCanvas("up_velvetGloves") {
    for (dx, rot, col) in [(-34.0, -0.3, P.velvetLight), (34.0, 0.3, P.teal)] {
        ctx.saveGState(); ctx.translateBy(x: 120 + CGFloat(dx), y: 128); ctx.rotate(by: CGFloat(rot))
        let g = CGMutablePath()
        g.addPath(rr(CGRect(x: -34, y: -20, width: 68, height: 70), 26))
        for f in 0..<4 { g.addPath(rr(CGRect(x: -32 + CGFloat(f) * 17, y: -74, width: 15, height: 64), 7.5)) }
        g.addPath(rr(CGRect(x: 26, y: -16, width: 34, height: 16), 8))
        stroke(g, P.outline, 10); fill(g, col)
        fill(rr(CGRect(x: -38, y: 40, width: 76, height: 26), 8), P.gold); stroke(rr(CGRect(x: -38, y: 40, width: 76, height: 26), 8), P.outline, 5)
        ctx.restoreGState()
    }
}

propCanvas("up_silkSleeves") {
    let s = CGMutablePath()
    s.move(to: pt(60, 40)); s.addCurve(to: pt(200, 200), control1: pt(200, 40), control2: pt(60, 200))
    s.addLine(to: pt(150, 214)); s.addCurve(to: pt(30, 70), control1: pt(30, 210), control2: pt(150, 60)); s.closeSubpath()
    harlequin(s, P.teal, P.saffron, cell: 34, bounds: CGRect(x: 20, y: 30, width: 200, height: 200))
    stroke(s, P.outline, 6)
    fill(ellipse(CGRect(x: 26, y: 30, width: 48, height: 46)), P.ivory); stroke(ellipse(CGRect(x: 26, y: 30, width: 48, height: 46)), P.outline, 5)
    for (x, y) in [(88.0, 80.0), (150.0, 150.0)] { fill(starPath(pt(x, y), 12, 3), Col.white.alpha(0.8)) }
}

propCanvas("up_silverBells") {
    for (c, r) in [(pt(80, 120), CGFloat(40)), (pt(160, 120), CGFloat(40)), (pt(120, 80), CGFloat(44))] {
        ctx.saveGState()
        let silver = { (rect: CGRect) in
            let b = CGMutablePath()
            b.move(to: pt(rect.midX, rect.minY))
            b.addCurve(to: pt(rect.maxX, rect.maxY), control1: pt(rect.maxX - 6, rect.minY), control2: pt(rect.maxX - 12, rect.maxY - 20))
            b.addLine(to: pt(rect.minX, rect.maxY))
            b.addCurve(to: pt(rect.midX, rect.minY), control1: pt(rect.minX + 12, rect.maxY - 20), control2: pt(rect.minX + 6, rect.minY))
            linearFill(b, [Col.white, Col(hex: 0xC7CEDF), Col(hex: 0x7E8AA6)], pt(rect.minX, rect.minY), pt(rect.maxX, rect.maxY))
            stroke(b, P.outline, 5)
            fill(circle(pt(rect.midX, rect.maxY + 6), 9), Col(hex: 0x7E8AA6)); stroke(circle(pt(rect.midX, rect.maxY + 6), 9), P.outline, 4)
        }
        silver(CGRect(x: c.x - r, y: c.y - r * 0.4, width: r * 2, height: r * 1.8))
        ctx.restoreGState()
    }
    line(pt(80, 72), pt(120, 30), P.rose, 7); line(pt(160, 72), pt(120, 30), P.rose, 7)
    fill(circle(pt(120, 30), 12), P.rose); stroke(circle(pt(120, 30), 12), P.outline, 4)
}

propCanvas("up_courtFavor") {
    // Laurel wreath around a wax seal.
    for side in [-1.0, 1.0] {
        let s = CGFloat(side)
        for k in 0..<7 {
            let a = CGFloat.pi * 0.5 + s * (CGFloat(k) * 0.36 + 0.25)
            let p = pt(120 + cos(a) * 78, 122 + sin(a) * 78)
            ctx.saveGState(); ctx.translateBy(x: p.x, y: p.y); ctx.rotate(by: a + s * 0.9)
            let leaf = ellipse(CGRect(x: -12, y: -24, width: 24, height: 48))
            fill(leaf, Col(hex: 0x3C8A47)); stroke(leaf, P.outline, 4)
            ctx.restoreGState()
        }
    }
    let seal = CGMutablePath()
    for p in regularPolygon(pt(120, 122), 46, sides: 14) { seal.addPath(circle(p, 14)) }
    seal.addPath(circle(pt(120, 122), 48))
    fill(seal, P.rose); stroke(seal, P.outline, 5)
    drawCrown(CGRect(x: 92, y: 98, width: 56, height: 44))
}

propCanvas("up_lanternOil") {
    let flask = CGMutablePath()
    flask.move(to: pt(100, 40)); flask.addLine(to: pt(140, 40)); flask.addLine(to: pt(140, 76))
    flask.addCurve(to: pt(140, 214), control1: pt(210, 100), control2: pt(210, 214))
    flask.addLine(to: pt(100, 214)); flask.addCurve(to: pt(100, 76), control1: pt(30, 214), control2: pt(30, 100)); flask.closeSubpath()
    linearFill(flask, [Col(hex: 0xBFE7EC, 0.9), Col(hex: 0x7FBFCB, 0.9)], pt(60, 40), pt(180, 214))
    ctx.saveGState(); ctx.addPath(flask); ctx.clip()
    linearFill(CGPath(rect: CGRect(x: 0, y: 128, width: 240, height: 120), transform: nil), [P.saffron, P.goldDeep], pt(0, 128), pt(0, 220))
    ctx.restoreGState()
    stroke(flask, P.outline, 6)
    fill(rr(CGRect(x: 92, y: 24, width: 56, height: 24), 6), P.woodDark); stroke(rr(CGRect(x: 92, y: 24, width: 56, height: 24), 6), P.outline, 5)
    fill(ellipse(CGRect(x: 78, y: 96, width: 18, height: 52)), Col.white.alpha(0.5))
    drawCandle(pt(170, 214), height: 40, width: 18, glowStrength: 0.9)
}

propCanvas("up_jingleCharm") {
    let chain = CGMutablePath()
    chain.move(to: pt(60, 30)); chain.addQuadCurve(to: pt(180, 30), control: pt(120, 110))
    ctx.setLineDash(phase: 0, lengths: [10, 6]); stroke(chain, P.goldDeep, 6); ctx.setLineDash(phase: 0, lengths: [])
    fill(starPath(pt(120, 132), 86, 40, points: 8, rotation: 0.2), P.teal.alpha(0.9))
    stroke(starPath(pt(120, 132), 86, 40, points: 8, rotation: 0.2), P.outline, 5)
    bell(pt(120, 132), 42)
    fill(starPath(pt(92, 100), 16, 4), Col.white)
}

// MARK: Decree icons (120 x 120)

func scrollBadge(_ name: String, _ body: () -> Void) {
    begin(120, 120)
    let paper = rr(CGRect(x: 14, y: 16, width: 92, height: 88), 12)
    linearFill(paper, [P.ivory, P.parchment, P.parchmentDark], pt(0, 16), pt(0, 104))
    stroke(paper, P.goldDeep, 4)
    fill(rr(CGRect(x: 8, y: 10, width: 104, height: 14), 7), P.parchmentDark); stroke(rr(CGRect(x: 8, y: 10, width: 104, height: 14), 7), P.goldDeep, 3)
    fill(rr(CGRect(x: 8, y: 96, width: 104, height: 14), 7), P.parchmentDark); stroke(rr(CGRect(x: 8, y: 96, width: 104, height: 14), 7), P.goldDeep, 3)
    body()
    finish(name)
}

scrollBadge("decree_rubyHour") {
    drawGem("ruby", CGRect(x: 22, y: 30, width: 52, height: 52))
    // Hourglass.
    let h = poly([pt(76, 34), pt(104, 34), pt(90, 60), pt(104, 86), pt(76, 86), pt(90, 60)])
    fill(h, Col(hex: 0xBFE3EA, 0.8)); stroke(h, P.woodDark, 4)
    fill(poly([pt(82, 80), pt(98, 80), pt(90, 68)]), P.saffron)
}
scrollBadge("decree_rottenTomatoes") {
    let t = ellipse(CGRect(x: 30, y: 36, width: 60, height: 54))
    radialFill(t, [Col(hex: 0xE5583A), Col(hex: 0x9A2414)], pt(50, 52), 60)
    stroke(t, Col(hex: 0x5A120A), 4)
    line(pt(60, 38), pt(64, 28), Col(hex: 0x3E7A2C), 5)
    line(pt(28, 30), pt(94, 96), P.rose, 7)
}
scrollBadge("decree_candleGust") {
    drawCandle(pt(52, 92), height: 36, width: 16, glowStrength: 0.4)
    for k in 0..<3 {
        let w = CGMutablePath(); let y = CGFloat(40 + k * 16)
        w.move(to: pt(68, y)); w.addQuadCurve(to: pt(102, y - 4), control: pt(86, y + 10))
        stroke(w, P.velvetLight, 5)
    }
}

// MARK: Particles

begin(64, 64); glow(pt(32, 32), 32, Col.white); finish("p_soft")
begin(64, 64); fill(starPath(pt(32, 32), 30, 7), Col.white); glow(pt(32, 32), 14, Col.white); finish("p_spark")
begin(48, 48); fill(poly([pt(8, 40), pt(24, 4), pt(42, 30)]), Col.white); stroke(poly([pt(8, 40), pt(24, 4), pt(42, 30)]), Col(0.8, 0.85, 1), 2); finish("p_shard")
begin(48, 48); do { let p = CGMutablePath(); p.move(to: pt(24, 4)); p.addQuadCurve(to: pt(24, 44), control: pt(48, 22)); p.addQuadCurve(to: pt(24, 4), control: pt(0, 22)); fill(p, P.rose); fill(ellipse(CGRect(x: 18, y: 12, width: 8, height: 16)), Col.white.alpha(0.35)) }; finish("p_petal")
begin(64, 64)
do {
    var g = Rng(s: 5)
    let p = CGMutablePath(); p.addPath(circle(pt(32, 32), 18))
    for _ in 0..<7 { let a = g.r(0, .pi * 2); let d = g.r(16, 26); p.addPath(circle(pt(32 + cos(a) * d, 32 + sin(a) * d), g.r(4, 8))) }
    fill(p, Col.white)
}
finish("p_juice")
begin(128, 40); radialFill(ellipse(CGRect(x: 0, y: 0, width: 128, height: 40)), [Col(0, 0, 0.05, 0.7), Col(0, 0, 0.05, 0)], pt(64, 20), 64); finish("shadow_oval")
begin(600, 1200)
do {
    let cone = poly([pt(240, 0), pt(360, 0), pt(600, 1200), pt(0, 1200)])
    ctx.saveGState(); ctx.addPath(cone); ctx.clip()
    ctx.drawLinearGradient(gradient([Col(1, 0.93, 0.75, 0.0), Col(1, 0.9, 0.7, 0.35)], [0, 1]), start: pt(0, 0), end: pt(0, 1200), options: [])
    ctx.restoreGState()
    ctx.saveGState(); ctx.scaleBy(x: 1, y: 0.28)
    radialFill(ellipse(CGRect(x: 0, y: 3600, width: 600, height: 600)), [Col(1, 0.92, 0.7, 0.55), Col(1, 0.9, 0.7, 0)], pt(300, 3900), 300)
    ctx.restoreGState()
}
finish("spotlight")

// MARK: - Backdrops

func pillar(_ r: CGRect) {
    linearFill(CGPath(rect: r, transform: nil), [Col(hex: 0x0E0B22), Col(hex: 0x2A2552), Col(hex: 0x15112F)], pt(r.minX, 0), pt(r.maxX, 0))
    for y in stride(from: r.minY + 90, to: r.maxY, by: 180) { line(pt(r.minX, y), pt(r.maxX, y), Col(hex: 0x0A081A, 0.7), 4) }
    line(pt(r.minX + r.width * 0.3, r.minY), pt(r.minX + r.width * 0.3, r.maxY), Col(hex: 0x4A4486, 0.35), 6)
}

func gothicWindow(_ r: CGRect, moonY: CGFloat?, night: CGFloat, seed: UInt64) {
    let p = CGMutablePath()
    p.move(to: pt(r.minX, r.maxY))
    p.addLine(to: pt(r.minX, r.minY + r.width * 0.5))
    p.addQuadCurve(to: pt(r.midX, r.minY), control: pt(r.minX, r.minY + r.width * 0.05))
    p.addQuadCurve(to: pt(r.maxX, r.minY + r.width * 0.5), control: pt(r.maxX, r.minY + r.width * 0.05))
    p.addLine(to: pt(r.maxX, r.maxY))
    p.closeSubpath()
    stroke(p, Col(hex: 0x0A0818), 36)
    linearFill(p, [Col(hex: 0x1B2A5E).darker(night * 0.4), Col(hex: 0x2E4C8A).darker(night * 0.45), Col(hex: 0x16204A)], pt(0, r.minY), pt(0, r.maxY))
    ctx.saveGState(); ctx.addPath(p); ctx.clip()
    var g = Rng(s: seed)
    for _ in 0..<40 { fill(circle(pt(g.r(r.minX, r.maxX), g.r(r.minY, r.maxY)), g.r(1.5, 4)), Col.white.alpha(g.r(0.4, 0.9))) }
    if let moonY {
        glow(pt(r.midX + r.width * 0.12, moonY), r.width * 0.55, Col(hex: 0xBFD4FF, 0.35))
        fill(circle(pt(r.midX + r.width * 0.12, moonY), r.width * 0.16), Col(hex: 0xF3F0DC))
        fill(circle(pt(r.midX + r.width * 0.2, moonY - r.width * 0.04), r.width * 0.14), Col(hex: 0x2E4C8A).darker(night * 0.45))
    }
    ctx.restoreGState()
    // Leaded mullions.
    line(pt(r.midX, r.minY), pt(r.midX, r.maxY), Col(hex: 0x0A0818), 12)
    for k in 1..<5 { line(pt(r.minX, r.minY + r.height * CGFloat(k) / 5 + r.width * 0.2), pt(r.maxX, r.minY + r.height * CGFloat(k) / 5 + r.width * 0.2), Col(hex: 0x0A0818), 8) }
    stroke(p, P.goldDeep.alpha(0.7), 6)
}

func pennant(_ r: CGRect, _ a: Col, _ b: Col) {
    let p = poly([pt(r.minX, r.minY), pt(r.maxX, r.minY), pt(r.maxX, r.maxY), pt(r.midX, r.maxY - r.width * 0.45), pt(r.minX, r.maxY)])
    harlequin(p, a, b, cell: r.width / 3, bounds: r)
    ctx.saveGState(); ctx.addPath(p); ctx.clip()
    ctx.drawLinearGradient(gradient([Col(0, 0, 0.05, 0.1), Col(0, 0, 0.05, 0.55)]), start: pt(0, r.minY), end: pt(0, r.maxY), options: [])
    ctx.restoreGState()
    stroke(p, P.goldDeep, 6)
    fill(rr(CGRect(x: r.minX - 16, y: r.minY - 18, width: r.width + 32, height: 26), 13), P.goldDeep)
}

/// Banquet hall behind the play field. Stage 0...3: the candles burn down as the night goes on.
func drawHall(stage: Int) {
    let w: CGFloat = 1170, h: CGFloat = 2532
    begin(Int(w), Int(h))
    let burn: [CGFloat] = [1, 0.74, 0.5, 0.26]
    let light: [CGFloat] = [1, 0.85, 0.66, 0.45]
    let b = burn[stage], l = light[stage]
    let full = CGPath(rect: CGRect(x: 0, y: 0, width: w, height: h), transform: nil)
    linearFill(full, [Col(hex: 0x0D0B24), Col(hex: 0x1D1848), Col(hex: 0x141034)], pt(0, 0), pt(0, h), [0, 0.55, 1])
    // Faint diamond damask on the wall.
    ctx.saveGState(); ctx.setAlpha(0.18)
    harlequin(full, Col(hex: 0x1D1848), Col(hex: 0x2C2766), cell: 130, bounds: CGRect(x: 0, y: 0, width: w, height: h))
    ctx.restoreGState()
    linearFill(full, [Col(hex: 0x0D0B24, 0.0), Col(hex: 0x0D0B24, 0.0), Col(hex: 0x0D0B24, 0.5)], pt(0, 0), pt(0, h), [0, 0.6, 1])

    let moonY: [CGFloat] = [560, 500, 440, 380]
    gothicWindow(CGRect(x: 250, y: 330, width: 250, height: 820), moonY: moonY[stage], night: CGFloat(stage) / 3, seed: 11)
    gothicWindow(CGRect(x: 670, y: 330, width: 250, height: 820), moonY: nil, night: CGFloat(stage) / 3, seed: 12)

    pennant(CGRect(x: 520, y: 180, width: 130, height: 560), P.teal.darker(0.25), P.saffron.darker(0.3))
    pennant(CGRect(x: 160, y: 140, width: 70, height: 340), P.rose.darker(0.35), P.ivory.darker(0.4))
    pennant(CGRect(x: 940, y: 140, width: 70, height: 340), P.rose.darker(0.35), P.ivory.darker(0.4))

    pillar(CGRect(x: 0, y: 0, width: 130, height: h))
    pillar(CGRect(x: w - 130, y: 0, width: 130, height: h))

    // Wall candelabras.
    for x in [CGFloat(65), w - 65] {
        let arm = CGMutablePath(); arm.move(to: pt(x, 1420)); arm.addLine(to: pt(x, 1340))
        arm.move(to: pt(x - 60, 1330)); arm.addQuadCurve(to: pt(x + 60, 1330), control: pt(x, 1420))
        stroke(arm, P.goldDeep, 12)
        for dx in [CGFloat(-60), 0, 60] { drawCandle(pt(x + dx, 1330), height: 110 * b + 14, width: 26, glowStrength: l) }
    }

    // Chandelier.
    line(pt(w / 2, 0), pt(w / 2, 90), P.goldDeep, 10)
    let ring = ellipse(CGRect(x: w / 2 - 260, y: 120, width: 520, height: 80))
    stroke(ring, P.goldDeep, 16); stroke(ring, P.gold.alpha(0.6), 5)
    for k in 0..<7 {
        let x = w / 2 - 240 + CGFloat(k) * 80
        drawCandle(pt(x, 150 + abs(CGFloat(k) - 3) * -6 + 18), height: 90 * b + 12, width: 22, glowStrength: l)
    }
    glow(pt(w / 2, 160), 520, P.candle.alpha(0.16 * l))

    // Wainscot.
    let wains = CGRect(x: 130, y: 1700, width: w - 260, height: 520)
    linearFill(CGPath(rect: wains, transform: nil), [P.woodDark.darker(0.2), P.woodDark.darker(0.5)], pt(0, wains.minY), pt(0, wains.maxY))
    for k in 0..<5 {
        let pr = CGRect(x: wains.minX + 30 + CGFloat(k) * (wains.width - 60) / 5, y: wains.minY + 40, width: (wains.width - 60) / 5 - 24, height: wains.height - 90)
        stroke(rr(pr, 12), P.goldDeep.alpha(0.5), 6)
    }
    line(pt(130, 1700), pt(w - 130, 1700), P.goldDeep, 12)
    // Warm candlelight pooling on the lower wall, fading with the night.
    glow(pt(w / 2, 2000), 700, P.flame.alpha(0.14 * l))
    // Floor (mostly hidden behind the stage strip).
    linearFill(CGPath(rect: CGRect(x: 0, y: 2220, width: w, height: h - 2220), transform: nil), [P.woodDark, Col(hex: 0x1A0F08)], pt(0, 2220), pt(0, h))
    // Vignette.
    ctx.saveGState()
    ctx.drawRadialGradient(gradient([Col(0, 0, 0, 0), Col(0, 0, 0.03, 0.55)]), startCenter: pt(w / 2, h * 0.45), startRadius: w * 0.4, endCenter: pt(w / 2, h * 0.45), endRadius: h * 0.75, options: [.drawsAfterEndLocation])
    ctx.restoreGState()
    finish("bg_hall_\(stage)")
}

for stage in 0...3 { drawHall(stage: stage) }

func curtainPanel(_ r: CGRect, flip: Bool, seed: UInt64) {
    let p = CGMutablePath()
    if !flip {
        p.move(to: pt(r.minX, r.minY)); p.addLine(to: pt(r.maxX, r.minY))
        p.addQuadCurve(to: pt(r.minX + r.width * 0.55, r.maxY * 0.55), control: pt(r.maxX - r.width * 0.05, r.maxY * 0.32))
        p.addQuadCurve(to: pt(r.minX + r.width * 0.8, r.maxY), control: pt(r.minX + r.width * 0.45, r.maxY * 0.78))
        p.addLine(to: pt(r.minX, r.maxY))
    } else {
        p.move(to: pt(r.maxX, r.minY)); p.addLine(to: pt(r.minX, r.minY))
        p.addQuadCurve(to: pt(r.maxX - r.width * 0.55, r.maxY * 0.55), control: pt(r.minX + r.width * 0.05, r.maxY * 0.32))
        p.addQuadCurve(to: pt(r.maxX - r.width * 0.8, r.maxY), control: pt(r.maxX - r.width * 0.45, r.maxY * 0.78))
        p.addLine(to: pt(r.maxX, r.maxY))
    }
    p.closeSubpath()
    ctx.saveGState(); ctx.addPath(p); ctx.clip()
    fill(CGPath(rect: r, transform: nil), Col(hex: 0x231C5E))
    let folds = 7
    for k in 0..<folds {
        let x = r.minX + CGFloat(k) / CGFloat(folds) * r.width
        let fw = r.width / CGFloat(folds)
        ctx.drawLinearGradient(gradient([Col(hex: 0x0E0A2C), Col(hex: 0x3A3290), Col(hex: 0x241D62), Col(hex: 0x0E0A2C)], [0, 0.35, 0.6, 1]), start: pt(x, 0), end: pt(x + fw, 0), options: [])
    }
    ctx.drawLinearGradient(gradient([Col(0, 0, 0, 0.35), Col(0, 0, 0, 0), Col(0, 0, 0, 0.45)], [0, 0.4, 1]), start: pt(0, r.minY), end: pt(0, r.maxY), options: [])
    ctx.restoreGState()
    // Gold edge trim along the inner curve.
    ctx.saveGState(); ctx.addPath(p); ctx.setLineWidth(18); ctx.setStrokeColor(P.gold.cg); ctx.replacePathWithStrokedPath(); ctx.clip()
    linearFill(CGPath(rect: r.insetBy(dx: -20, dy: -20), transform: nil), [P.goldLight, P.goldDeep], pt(r.minX, 0), pt(r.maxX, 0))
    ctx.restoreGState()
    // Tie-back rope with tassel.
    let tieX = flip ? r.maxX - r.width * 0.42 : r.minX + r.width * 0.42
    let tieY = r.maxY * 0.56
    let rope = ellipse(CGRect(x: tieX - r.width * 0.26, y: tieY - 24, width: r.width * 0.52, height: 48))
    stroke(rope, P.goldDeep, 22); stroke(rope, P.saffron, 10)
    drawTassel(CGRect(x: tieX - 26, y: tieY + 10, width: 52, height: 130), lit: true)
}

/// Home: a candlelit proscenium stage.
do {
    let w: CGFloat = 1170, h: CGFloat = 2532
    begin(Int(w), Int(h))
    let full = CGPath(rect: CGRect(x: 0, y: 0, width: w, height: h), transform: nil)
    linearFill(full, [Col(hex: 0x0B0920), Col(hex: 0x1A1546), Col(hex: 0x100C2C)], pt(0, 0), pt(0, h), [0, 0.6, 1])
    ctx.saveGState(); ctx.setAlpha(0.22)
    harlequin(CGPath(rect: CGRect(x: 0, y: 300, width: w, height: 1700), transform: nil), Col(hex: 0x1A1546), Col(hex: 0x2B2672), cell: 150, bounds: CGRect(x: 0, y: 300, width: w, height: 1700))
    ctx.restoreGState()
    // Spotlight cone onto the stage.
    ctx.saveGState()
    let cone = poly([pt(w * 0.42, 0), pt(w * 0.58, 0), pt(w * 0.86, 2050), pt(w * 0.14, 2050)])
    ctx.addPath(cone); ctx.clip()
    ctx.drawLinearGradient(gradient([Col(1, 0.92, 0.72, 0.02), Col(1, 0.9, 0.7, 0.22)]), start: pt(0, 0), end: pt(0, 2050), options: [])
    ctx.restoreGState()
    // Stage floor.
    let floorTop: CGFloat = 1960
    let stageFloor = poly([pt(0, floorTop), pt(w, floorTop), pt(w, h), pt(0, h)])
    linearFill(stageFloor, [Col(hex: 0x6E4122), Col(hex: 0x3E2312)], pt(0, floorTop), pt(0, h))
    for k in 0..<14 {
        let x0 = w / 2 + (CGFloat(k) - 6.5) * 70
        let x1 = w / 2 + (CGFloat(k) - 6.5) * 180
        line(pt(x0, floorTop), pt(x1, h), Col(hex: 0x2A160A, 0.6), 4)
    }
    for k in 1..<6 { let y = floorTop + CGFloat(k * k) * 22; line(pt(0, y), pt(w, y), Col(hex: 0x2A160A, 0.4), 3) }
    ctx.saveGState(); ctx.scaleBy(x: 1, y: 0.3)
    radialFill(ellipse(CGRect(x: w * 0.12, y: (floorTop + 60) / 0.3, width: w * 0.76, height: 900)), [Col(1, 0.9, 0.65, 0.45), Col(1, 0.9, 0.65, 0)], pt(w / 2, (floorTop + 300) / 0.3), w * 0.4)
    ctx.restoreGState()
    line(pt(0, floorTop), pt(w, floorTop), P.goldDeep, 10)
    // Footlights.
    for k in 0..<9 {
        let x = 70 + CGFloat(k) * (w - 140) / 8
        let shell = CGMutablePath(); shell.addArc(center: pt(x, h - 120), radius: 46, startAngle: .pi, endAngle: 0, clockwise: false); shell.closeSubpath()
        drawCandle(pt(x, h - 130), height: 50, width: 18, glowStrength: 0.8)
        fill(shell, P.goldDeep); stroke(shell, P.outline, 4)
    }
    curtainPanel(CGRect(x: -20, y: 0, width: 380, height: h), flip: false, seed: 3)
    curtainPanel(CGRect(x: w - 360, y: 0, width: 380, height: h), flip: true, seed: 4)
    // Valance with swags.
    let val = CGMutablePath()
    val.move(to: pt(0, 0)); val.addLine(to: pt(w, 0)); val.addLine(to: pt(w, 170))
    let swags = 5
    for k in 0..<swags {
        let x1 = w - CGFloat(k + 1) * w / CGFloat(swags)
        val.addQuadCurve(to: pt(x1, 170), control: pt(x1 + w / CGFloat(swags) / 2, 330))
    }
    val.closeSubpath()
    ctx.saveGState(); ctx.addPath(val); ctx.clip()
    ctx.drawLinearGradient(gradient([Col(hex: 0x120E36), Col(hex: 0x332A85), Col(hex: 0x1C165A)], [0, 0.6, 1]), start: pt(0, 0), end: pt(0, 330), options: [])
    ctx.restoreGState()
    ctx.saveGState(); ctx.addPath(val); ctx.setLineWidth(16); ctx.replacePathWithStrokedPath(); ctx.clip()
    linearFill(CGPath(rect: CGRect(x: 0, y: 0, width: w, height: 340), transform: nil), [P.goldLight, P.goldDeep], pt(0, 150), pt(0, 340))
    ctx.restoreGState()
    for k in 0...swags {
        let x = w - CGFloat(k) * w / CGFloat(swags)
        drawTassel(CGRect(x: x - 26, y: 160, width: 52, height: 120), lit: true)
    }
    finish("bg_stage")
}

/// Floor band under the play field: the stage lip, boards and footlights.
do {
    let w: CGFloat = 1170, h: CGFloat = 420
    begin(Int(w), Int(h))
    let boards = CGRect(x: 0, y: 0, width: w, height: 190)
    linearFill(CGPath(rect: boards, transform: nil), [Col(hex: 0x8A5530), Col(hex: 0x5A331A)], pt(0, 0), pt(0, 190))
    for k in 0..<12 { let x = CGFloat(k) * 104 + 20; line(pt(x, 0), pt(x - 30, 190), Col(hex: 0x3A1F0E, 0.7), 4) }
    line(pt(0, 70), pt(w, 70), Col(hex: 0x3A1F0E, 0.35), 3)
    line(pt(0, 2), pt(w, 2), Col(hex: 0xC48A52, 0.8), 4)
    // Apron with gilded edge.
    let apron = CGRect(x: 0, y: 190, width: w, height: h - 190)
    linearFill(CGPath(rect: apron, transform: nil), [Col(hex: 0x1C1440), Col(hex: 0x0B0820)], pt(0, 190), pt(0, h))
    linearFill(CGPath(rect: CGRect(x: 0, y: 186, width: w, height: 22), transform: nil), [P.goldLight, P.gold, P.goldDeep], pt(0, 186), pt(0, 208))
    for k in 0..<12 {
        let x = 50 + CGFloat(k) * 97
        fill(poly([pt(x, 226), pt(x + 18, 250), pt(x, 274), pt(x - 18, 250)]), P.goldDeep.alpha(0.55))
    }
    finish("stage_floor")
}

// MARK: - Tiles (300 x 300, seamless)

begin(300, 300)
do {
    let full = CGPath(rect: CGRect(x: 0, y: 0, width: 300, height: 300), transform: nil)
    radialFill(full, [Col(hex: 0x272066), Col(hex: 0x1B1650)], pt(150, 150), 260)
    // Lattice: diamonds 100 x 150 repeat exactly twice per tile.
    for i in -1...4 {
        line(pt(CGFloat(i) * 100 - 150, 0), pt(CGFloat(i) * 100 + 50, 300), P.gold.alpha(0.13), 3)
        line(pt(CGFloat(i) * 100 + 150, 0), pt(CGFloat(i) * 100 - 50, 300), P.gold.alpha(0.13), 3)
    }
    for x in stride(from: 0.0, through: 300.0, by: 100.0) { for y in stride(from: 0.0, through: 300.0, by: 150.0) { fill(circle(pt(x, y), 4), P.saffron.alpha(0.3)); fill(circle(pt(x + 50, y + 75), 4), P.saffron.alpha(0.3)) } }
}
finish("tile_velvet")

begin(300, 300)
do {
    for k in 0..<3 {
        let r = CGRect(x: CGFloat(k) * 100, y: 0, width: 100, height: 300)
        let base = [Col(hex: 0x6B3F20), Col(hex: 0x75472A), Col(hex: 0x633A1E)][k]
        fill(CGPath(rect: r, transform: nil), base)
        for g in 0..<6 {
            let p = CGMutablePath()
            let x0 = r.minX + 10 + CGFloat(g) * 15
            p.move(to: pt(x0, 0))
            for y in stride(from: 0.0, through: 300.0, by: 10.0) { p.addLine(to: pt(x0 + sin(CGFloat(y) / 300 * .pi * 2 * 2 + CGFloat(g)) * 5, CGFloat(y))) }
            stroke(p, base.darker(0.25).alpha(0.6), 2)
        }
        line(pt(r.minX + 1, 0), pt(r.minX + 1, 300), Col(hex: 0x2A160A), 4)
    }
}
finish("tile_wood")

begin(300, 300)
do {
    fill(CGPath(rect: CGRect(x: 0, y: 0, width: 300, height: 300), transform: nil), Col(hex: 0x1E1A3A))
    for row in 0..<6 {
        let y = CGFloat(row) * 50
        let offset: CGFloat = row % 2 == 0 ? 0 : 50
        for k in -1..<3 {
            let r = CGRect(x: CGFloat(k) * 100 + offset + 3, y: y + 3, width: 94, height: 44)
            fill(rr(r, 6), Col(hex: 0x29244C).mix(Col(hex: 0x332D5C), CGFloat((row * 7 + k * 3 + 9) % 5) / 5))
        }
    }
}
finish("tile_wall")

// MARK: - 9-slice panels and buttons

begin(720, 480)
do {
    let r = CGRect(x: 6, y: 6, width: 708, height: 468)
    shadowed(4, 10, Col(0, 0, 0.05, 0.4)) { fill(rr(r, 30), P.parchmentDark) }
    linearFill(rr(r.insetBy(dx: 4, dy: 4), 26), [P.ivory, P.parchment], pt(0, r.minY), pt(0, r.maxY))
    stroke(rr(r.insetBy(dx: 22, dy: 22), 18), P.gold, 5)
    stroke(rr(r.insetBy(dx: 34, dy: 34), 12), P.gold.alpha(0.55), 2.5)
    for c in [pt(r.minX + 40, r.minY + 40), pt(r.maxX - 40, r.minY + 40), pt(r.minX + 40, r.maxY - 40), pt(r.maxX - 40, r.maxY - 40)] {
        fill(poly([pt(c.x, c.y - 18), pt(c.x + 18, c.y), pt(c.x, c.y + 18), pt(c.x - 18, c.y)]), P.teal)
        stroke(poly([pt(c.x, c.y - 18), pt(c.x + 18, c.y), pt(c.x, c.y + 18), pt(c.x - 18, c.y)]), P.goldDeep, 3)
        fill(circle(c, 4), P.saffron)
    }
    stroke(rr(r, 30), P.goldDeep, 5)
}
finish("panel_parchment")

begin(540, 540)
do {
    let r = CGRect(x: 6, y: 6, width: 528, height: 528)
    shadowed(4, 10, Col(0, 0, 0, 0.5)) { fill(rr(r, 36), Col(hex: 0x15113A)) }
    radialFill(rr(r.insetBy(dx: 3, dy: 3), 33), [Col(hex: 0x2E2774), Col(hex: 0x1A1548)], pt(200, 160), 460)
    ctx.setLineDash(phase: 0, lengths: [14, 10])
    stroke(rr(r.insetBy(dx: 26, dy: 26), 22), P.saffron.alpha(0.75), 4)
    ctx.setLineDash(phase: 0, lengths: [])
    for c in [pt(r.minX + 26, r.minY + 26), pt(r.maxX - 26, r.minY + 26), pt(r.minX + 26, r.maxY - 26), pt(r.maxX - 26, r.maxY - 26)] {
        fill(circle(c, 10), P.goldLight); stroke(circle(c, 10), P.goldDeep, 3)
    }
    stroke(rr(r, 36), P.gold, 6)
}
finish("panel_velvet")

begin(450, 600)
do {
    let r = CGRect(x: 8, y: 14, width: 434, height: 578)
    shadowed(5, 12, Col(0, 0, 0, 0.5)) { fill(CGPath(rect: r, transform: nil), P.parchmentDark) }
    linearFill(CGPath(rect: r.insetBy(dx: 5, dy: 5), transform: nil), [Col(hex: 0xF4E6C4), Col(hex: 0xE7D2A4)], pt(0, r.minY), pt(0, r.maxY))
    stroke(CGPath(rect: r.insetBy(dx: 18, dy: 18), transform: nil), P.rose.alpha(0.8), 4)
    stroke(CGPath(rect: r.insetBy(dx: 28, dy: 28), transform: nil), P.rose.alpha(0.4), 2)
    for c in [pt(r.minX + 34, r.minY + 10), pt(r.maxX - 34, r.minY + 10)] {
        fill(circle(pt(c.x + 2, c.y + 4), 12), Col(0, 0, 0, 0.3))
        radialFill(circle(c, 12), [Col(hex: 0xFF8A8A), P.rose], pt(c.x - 3, c.y - 3), 16)
    }
}
finish("panel_poster")

begin(600, 150)
do {
    let body = CGRect(x: 50, y: 22, width: 500, height: 106)
    shadowed(3, 6, Col(0, 0, 0, 0.35)) { fill(CGPath(rect: body, transform: nil), P.parchmentDark) }
    linearFill(CGPath(rect: body.insetBy(dx: 0, dy: 3), transform: nil), [P.ivory, P.parchment, P.parchmentDark.lighter(0.3)], pt(0, body.minY), pt(0, body.maxY))
    line(pt(body.minX, body.minY + 3), pt(body.maxX, body.minY + 3), P.goldDeep.alpha(0.6), 3)
    line(pt(body.minX, body.maxY - 3), pt(body.maxX, body.maxY - 3), P.goldDeep.alpha(0.6), 3)
    for x in [CGFloat(36), 564] {
        let roll = rr(CGRect(x: x - 26, y: 8, width: 52, height: 134), 26)
        linearFill(roll, [P.parchmentDark, P.ivory, P.parchmentDark.darker(0.15)], pt(x - 26, 0), pt(x + 26, 0))
        stroke(roll, P.goldDeep, 4)
        fill(ellipse(CGRect(x: x - 12, y: 12, width: 24, height: 14)), P.goldDeep.alpha(0.5))
    }
}
finish("panel_scroll")

begin(600, 150)
do {
    for side in [-1.0, 1.0] {
        let s = CGFloat(side)
        let cx: CGFloat = 300 + s * 230
        let tail = poly([pt(cx - s * 40, 40), pt(cx + s * 66, 40), pt(cx + s * 40, 84), pt(cx + s * 66, 128), pt(cx - s * 40, 128)])
        fill(tail, P.goldDeep); stroke(tail, P.outline, 4)
    }
    let band = CGRect(x: 60, y: 20, width: 480, height: 110)
    shadowed(3, 6, Col(0, 0, 0, 0.35)) { fill(rr(band, 10), P.gold) }
    linearFill(rr(band, 10), [P.goldLight, P.saffron, P.gold], pt(0, band.minY), pt(0, band.maxY))
    line(pt(band.minX, band.minY + 10), pt(band.maxX, band.minY + 10), P.goldDeep.alpha(0.5), 3)
    line(pt(band.minX, band.maxY - 10), pt(band.maxX, band.maxY - 10), P.goldDeep.alpha(0.5), 3)
    stroke(rr(band, 10), P.outline, 4)
}
finish("ribbon")

func lacquerButton(_ name: String, top: Col, bottom: Col) {
    begin(600, 150)
    let r = CGRect(x: 6, y: 6, width: 588, height: 132)
    shadowed(6, 8, Col(0, 0, 0, 0.45)) { fill(rr(r, 50), P.goldDeep) }
    linearFill(rr(r, 50), [P.goldLight, P.gold, P.goldDeep], pt(0, r.minY), pt(0, r.maxY))
    let inner = r.insetBy(dx: 10, dy: 10)
    linearFill(rr(inner, 42), [top.lighter(0.2), top, bottom], pt(0, inner.minY), pt(0, inner.maxY))
    ctx.saveGState(); ctx.addPath(rr(inner, 42)); ctx.clip()
    fill(ellipse(CGRect(x: inner.minX + 30, y: inner.minY - 30, width: inner.width - 60, height: 70)), Col.white.alpha(0.22))
    ctx.restoreGState()
    stroke(rr(inner, 42), bottom.darker(0.35), 3)
    stroke(rr(r, 50), P.outline, 4)
    finish(name)
}

lacquerButton("btn_gold", top: Col(hex: 0xF9D07A), bottom: Col(hex: 0xE39A2E))
lacquerButton("btn_teal", top: Col(hex: 0x21958F), bottom: Col(hex: 0x0E5654))
lacquerButton("btn_plum", top: Col(hex: 0x4A3C8E), bottom: Col(hex: 0x24195A))

func medallion(_ name: String, _ symbol: (CGPoint) -> Void) {
    begin(150, 150)
    let c = pt(75, 75)
    shadowed(3, 6, Col(0, 0, 0, 0.5)) { fill(circle(c, 68), P.goldDeep) }
    radialFill(circle(c, 66), [P.goldLight, P.saffron, P.goldDeep], pt(55, 50), 100)
    fill(circle(c, 52), P.velvet)
    radialFill(circle(c, 52), [Col(hex: 0x3B3390), Col(hex: 0x1A1548)], pt(60, 55), 70)
    stroke(circle(c, 52), P.goldDeep, 4)
    for k in 0..<12 { let a = CGFloat(k) / 12 * .pi * 2; fill(circle(pt(c.x + cos(a) * 60, c.y + sin(a) * 60), 3), P.goldDeep) }
    symbol(c)
    stroke(circle(c, 68), P.outline, 4)
    finish(name)
}

medallion("med_back") { c in
    let a = CGMutablePath(); a.move(to: pt(c.x + 10, c.y - 24)); a.addLine(to: pt(c.x - 14, c.y)); a.addLine(to: pt(c.x + 10, c.y + 24))
    stroke(a, P.outline, 18); stroke(a, P.ivory, 10)
}
medallion("med_pause") { c in
    for dx in [CGFloat(-12), 12] { let b = rr(CGRect(x: c.x + dx - 7, y: c.y - 22, width: 14, height: 44), 5); fill(b, P.ivory); stroke(b, P.outline, 3) }
}
medallion("med_settings") { c in
    let sun = starPath(c, 32, 20, points: 8)
    fill(sun, P.ivory); stroke(sun, P.outline, 3)
    fill(circle(c, 11), P.velvet); stroke(circle(c, 11), P.outline, 3)
}
medallion("med_help") { c in
    fontText("?", pt(c.x, c.y + 2), font: "Copperplate-Bold", size: 66, color: P.ivory, stroke: P.outline, strokeWidth: 6)
}

// MARK: - Logo (1050 x 360)

begin(1050, 360)
do {
    // Juggling arc of gems above the wordmark.
    let arc = CGMutablePath(); arc.move(to: pt(170, 190)); arc.addQuadCurve(to: pt(880, 190), control: pt(525, -40))
    ctx.setLineDash(phase: 0, lengths: [6, 14]); stroke(arc, P.candle.alpha(0.7), 5); ctx.setLineDash(phase: 0, lengths: [])
    for (i, name) in ["sapphire", "emerald", "ruby", "topaz", "amethyst"].enumerated() {
        let t = CGFloat(i) / 4
        let x = 170 + (880 - 170) * t
        let y = 190 - 4 * (75 + 40) * t * (1 - t) * 0.9 - 10
        glow(pt(x, y), 80, gemColor(name).alpha(0.4))
        drawGem(name, CGRect(x: x - 44, y: y - 44, width: 88, height: 88))
    }
    fontText("JEWEL JUGGLER", pt(525, 258), font: "Copperplate-Bold", size: 118, color: P.saffron, stroke: P.outline, strokeWidth: 9, kern: 2)
    ctx.saveGState(); ctx.setBlendMode(.screen)
    fontText("JEWEL JUGGLER", pt(525, 254), font: "Copperplate-Bold", size: 118, color: P.goldLight.alpha(0.35), kern: 2)
    ctx.restoreGState()
    // Subtitle on a teal ribbon.
    let band = rr(CGRect(x: 330, y: 312, width: 390, height: 44), 22)
    fill(band, P.teal); stroke(band, P.outline, 4)
    fontText("A COURT OF GEMS", pt(525, 334), font: "Copperplate-Bold", size: 28, color: P.ivory, kern: 3)
}
finish("logo")

// MARK: - Tarot cards (288 x 462)

func tarot(_ name: String, _ art: (CGRect) -> Void) {
    begin(288, 462)
    let r = CGRect(x: 6, y: 6, width: 276, height: 450)
    shadowed(4, 8, Col(0, 0, 0, 0.5)) { fill(rr(r, 22), P.goldDeep) }
    linearFill(rr(r, 22), [P.goldLight, P.gold, P.goldDeep], pt(r.minX, r.minY), pt(r.maxX, r.maxY))
    let inner = r.insetBy(dx: 12, dy: 12)
    radialFill(rr(inner, 14), [Col(hex: 0x3A3290), Col(hex: 0x15113A)], pt(inner.midX, inner.minY + 120), 300)
    ctx.saveGState(); ctx.setAlpha(0.25)
    harlequin(rr(inner, 14), Col(hex: 0x15113A).alpha(0), Col(hex: 0x4A43A0), cell: 46, bounds: inner)
    ctx.restoreGState()
    stroke(rr(inner, 14), P.outline, 3)
    // Corner stars.
    for c in [pt(inner.minX + 18, inner.minY + 18), pt(inner.maxX - 18, inner.minY + 18)] { fill(starPath(c, 10, 3), P.saffron) }
    ctx.saveGState(); ctx.addPath(rr(inner, 14)); ctx.clip()
    art(CGRect(x: inner.minX, y: inner.minY + 20, width: inner.width, height: 270))
    ctx.restoreGState()
    // Parchment plate for the SwiftUI title.
    let plate = rr(CGRect(x: inner.minX + 10, y: inner.maxY - 128, width: inner.width - 20, height: 118), 12)
    linearFill(plate, [P.ivory, P.parchment], pt(0, inner.maxY - 128), pt(0, inner.maxY))
    stroke(plate, P.goldDeep, 4)
    stroke(rr(r, 22), P.outline, 4)
    finish(name)
}

tarot("card_wardrobe") { a in
    glow(pt(a.midX, a.midY), 140, P.candle.alpha(0.3))
    let hook = CGMutablePath(); hook.move(to: pt(a.midX, a.minY + 34)); hook.addCurve(to: pt(a.midX, a.minY + 4), control1: pt(a.midX + 24, a.minY + 34), control2: pt(a.midX + 24, a.minY))
    stroke(hook, P.goldLight, 6)
    line(pt(a.midX - 70, a.minY + 62), pt(a.midX, a.minY + 34), P.goldLight, 6); line(pt(a.midX + 70, a.minY + 62), pt(a.midX, a.minY + 34), P.goldLight, 6)
    drawJester(looks[0].1, frame: 1, in: CGRect(x: a.midX - 80, y: a.minY + 22, width: 160, height: 256))
}
tarot("card_trunk") { a in
    glow(pt(a.midX, a.midY + 20), 150, P.candle.alpha(0.4))
    drawChest(CGRect(x: a.midX - 110, y: a.midY - 50, width: 220, height: 190), open: true)
    fill(starPath(pt(a.midX - 70, a.minY + 50), 14, 3), Col.white.alpha(0.9))
    fill(starPath(pt(a.midX + 80, a.minY + 80), 10, 2.5), Col.white.alpha(0.9))
}
tarot("card_acts") { a in
    // A tiny stage: curtain swags and a rose in the spotlight.
    glow(pt(a.midX, a.midY + 40), 130, P.candle.alpha(0.45))
    for side in [-1.0, 1.0] {
        let s = CGFloat(side)
        let p = CGMutablePath()
        p.move(to: pt(a.midX + s * 132, a.minY)); p.addLine(to: pt(a.midX + s * 10, a.minY))
        p.addQuadCurve(to: pt(a.midX + s * 132, a.minY + 220), control: pt(a.midX + s * 60, a.minY + 150))
        p.closeSubpath()
        linearFill(p, [Col(hex: 0x8E1E33), P.rose, Col(hex: 0x5E1020)], pt(a.midX + s * 132, 0), pt(a.midX, 0))
        stroke(p, P.goldDeep, 4)
    }
    drawRose(pt(a.midX, a.midY + 50), 62, lit: true)
}
tarot("card_playbills") { a in
    ctx.saveGState(); ctx.translateBy(x: a.midX, y: a.midY + 10); ctx.rotate(by: -0.08)
    let poster = CGRect(x: -86, y: -118, width: 172, height: 236)
    fill(CGPath(rect: poster.offsetBy(dx: 6, dy: 8), transform: nil), Col(0, 0, 0, 0.35))
    linearFill(CGPath(rect: poster, transform: nil), [Col(hex: 0xF4E6C4), Col(hex: 0xE2C994)], pt(0, poster.minY), pt(0, poster.maxY))
    stroke(CGPath(rect: poster.insetBy(dx: 10, dy: 10), transform: nil), P.rose, 4)
    fontText("TONIGHT", pt(0, -86), font: "Copperplate-Bold", size: 26, color: P.rose)
    drawJester(looks[4].1, frame: 0, in: CGRect(x: -42, y: -68, width: 84, height: 134))
    for k in 0..<2 { line(pt(-56, 80 + CGFloat(k) * 16), pt(56, 80 + CGFloat(k) * 16), P.inkSoftCol, 5) }
    fill(circle(pt(0, -112), 9), P.rose)
    ctx.restoreGState()
    drawRosette(pt(a.maxX - 54, a.maxY - 70), 34, earned: true)
}
tarot("card_back") { a in
    harlequin(CGPath(rect: a.insetBy(dx: -20, dy: -40), transform: nil), P.teal.darker(0.3), P.saffron.darker(0.3), cell: 48, bounds: a.insetBy(dx: -20, dy: -40))
    drawCap(CGRect(x: a.midX - 80, y: a.midY - 90, width: 160, height: 160))
}

extension P { static let inkSoftCol = Col(hex: 0x4D405C) }

// MARK: - How to Play illustrations (900 x 700)

func guideScene(_ name: String, _ body: () -> Void) {
    begin(900, 700)
    let full = CGPath(rect: CGRect(x: 0, y: 0, width: 900, height: 700), transform: nil)
    linearFill(full, [Col(hex: 0x15113A), Col(hex: 0x241E5C), Col(hex: 0x15113A)], pt(0, 0), pt(0, 700))
    ctx.saveGState(); ctx.setAlpha(0.18)
    harlequin(full, Col(hex: 0x241E5C), Col(hex: 0x3A3290), cell: 90, bounds: CGRect(x: 0, y: 0, width: 900, height: 700))
    ctx.restoreGState()
    glow(pt(450, 560), 380, P.candle.alpha(0.18))
    // Stage boards.
    linearFill(CGPath(rect: CGRect(x: 0, y: 600, width: 900, height: 100), transform: nil), [Col(hex: 0x8A5530), Col(hex: 0x4A2A14)], pt(0, 600), pt(0, 700))
    line(pt(0, 600), pt(900, 600), P.goldDeep, 8)
    body()
    finish(name)
}

func jesterAt(_ x: CGFloat, frame: Int = 0, look: Int = 0, height: CGFloat = 300) {
    let w = height * 300 / 480
    fill(ellipse(CGRect(x: x - w * 0.45, y: 592, width: w * 0.9, height: 22)), Col(0, 0, 0, 0.35))
    drawJester(looks[look].1, frame: frame, in: CGRect(x: x - w / 2, y: 604 - height, width: w, height: height))
}

func dottedArc(_ from: CGPoint, _ to: CGPoint, height: CGFloat, color: Col = P.candle) {
    let p = CGMutablePath(); p.move(to: from); p.addQuadCurve(to: to, control: pt((from.x + to.x) / 2, min(from.y, to.y) - height))
    ctx.setLineDash(phase: 0, lengths: [8, 14]); stroke(p, color.alpha(0.85), 6); ctx.setLineDash(phase: 0, lengths: [])
}

func arrow(_ from: CGPoint, _ to: CGPoint, _ col: Col = P.saffron) {
    line(from, to, P.outline, 18); line(from, to, col, 10)
    let a = atan2(to.y - from.y, to.x - from.x)
    let head = poly([pt(to.x + cos(a) * 26, to.y + sin(a) * 26), pt(to.x + cos(a + 2.3) * 26, to.y + sin(a + 2.3) * 26), pt(to.x + cos(a - 2.3) * 26, to.y + sin(a - 2.3) * 26)])
    fill(head, col); stroke(head, P.outline, 4)
}

func finger(_ c: CGPoint) {
    fill(circle(c, 34), Col.white.alpha(0.25)); stroke(circle(c, 34), Col.white.alpha(0.8), 5)
    fill(circle(c, 14), Col.white.alpha(0.9))
}

func label(_ s: String, _ c: CGPoint, size: CGFloat = 40, color: Col = P.ivory) {
    fontText(s, c, font: "Copperplate-Bold", size: size, color: color, stroke: P.outline, strokeWidth: 6)
}

guideScene("guide_move") {
    jesterAt(450)
    arrow(pt(330, 480), pt(160, 480)); arrow(pt(570, 480), pt(740, 480))
    finger(pt(450, 660))
    drawGem("sapphire", CGRect(x: 640, y: 80, width: 90, height: 90))
    line(pt(685, 180), pt(685, 260), P.candle.alpha(0.6), 6)
}

guideScene("guide_catch") {
    jesterAt(450, frame: 1)
    dottedArc(pt(420, 300), pt(220, 300), height: 220)
    dottedArc(pt(480, 300), pt(690, 300), height: 260)
    drawGem("ruby", CGRect(x: 270, y: 110, width: 90, height: 90))
    drawGem("emerald", CGRect(x: 560, y: 90, width: 90, height: 90))
    drawGem("topaz", CGRect(x: 405, y: 230, width: 90, height: 90))
}

guideScene("guide_bank") {
    jesterAt(330, frame: 1)
    drawChest(CGRect(x: 600, y: 440, width: 200, height: 170), open: true)
    dottedArc(pt(330, 300), pt(700, 470), height: 200)
    drawGem("sapphire", CGRect(x: 470, y: 130, width: 90, height: 90))
    drawCoin(pt(760, 360), 40); drawCoin(pt(810, 400), 30)
    finger(pt(160, 160))
    label("TAP", pt(160, 240), size: 36)
}

guideScene("guide_wear") {
    for (i, stage) in [0, 1, 2, 3].enumerated() {
        let x = 110 + CGFloat(i) * 220
        drawGem("emerald", CGRect(x: x - 70, y: 200, width: 140, height: 140))
        if stage > 0 { drawCrackOverlay(stage, CGRect(x: x - 70, y: 200, width: 140, height: 140)) }
        label("\(stage)", pt(x, 400), size: 44, color: stage == 3 ? Col(1, 0.5, 0.4) : P.ivory)
        if i < 3 { arrow(pt(x + 80, 270), pt(x + 130, 270)) }
    }
    label("TOSSES", pt(450, 480), size: 44)
    drawChest(CGRect(x: 700, y: 480, width: 130, height: 110), open: true)
}

guideScene("guide_chord") {
    for k in 0..<3 { drawGem("ruby", CGRect(x: 60 + CGFloat(k) * 130, y: 230, width: 110, height: 110)) }
    arrow(pt(470, 285), pt(560, 285))
    glow(pt(720, 280), 200, P.goldLight.alpha(0.4))
    drawGem("ruby", CGRect(x: 630, y: 230, width: 180, height: 180))
    drawCrown(CGRect(x: 670, y: 150, width: 100, height: 70))
    label("×5", pt(720, 480), size: 60, color: P.saffron)
}

guideScene("guide_applause") {
    jesterAt(450, frame: 1, look: 6, height: 260)
    for (i, name) in ["ruby", "sapphire", "emerald", "topaz", "amethyst"].enumerated() {
        let x = 160 + CGFloat(i) * 145
        drawGem(name, CGRect(x: x - 40, y: 80 + CGFloat((i * 37) % 90), width: 80, height: 80))
    }
    for k in 0..<9 {
        let c = pt(50 + CGFloat(k) * 100, 660)
        fill(circle(pt(c.x, c.y - 4), 32), P.saffron); fill(circle(c, 30), Col(hex: 0x2A1B3E))
        line(pt(c.x - 26, c.y), pt(c.x - 40, c.y - 60), Col(hex: 0x2A1B3E), 12)
        line(pt(c.x + 26, c.y), pt(c.x + 40, c.y - 60), Col(hex: 0x2A1B3E), 12)
    }
    label("ENCORE ×2", pt(450, 340), size: 64, color: P.saffron)
}

guideScene("guide_decree") {
    let paper = rr(CGRect(x: 120, y: 80, width: 660, height: 440), 24)
    linearFill(paper, [P.ivory, P.parchment], pt(0, 80), pt(0, 520)); stroke(paper, P.goldDeep, 8)
    fontText("BY ROYAL DECREE", pt(450, 140), font: "Copperplate-Bold", size: 46, color: P.ink)
    drawGem("ruby", CGRect(x: 180, y: 200, width: 130, height: 130))
    let t = ellipse(CGRect(x: 390, y: 210, width: 120, height: 110))
    radialFill(t, [Col(hex: 0xE5583A), Col(hex: 0x9A2414)], pt(420, 240), 120); stroke(t, Col(hex: 0x5A120A), 6)
    drawCandle(pt(650, 330), height: 90, width: 34, glowStrength: 0.5)
    fontText("×3", pt(245, 380), font: "Copperplate-Bold", size: 40, color: P.rose)
    fontText("LET FALL", pt(450, 380), font: "Copperplate-Bold", size: 32, color: P.rose)
    fontText("DARK", pt(650, 380), font: "Copperplate-Bold", size: 32, color: P.rose)
    let seal = CGMutablePath(); for p in regularPolygon(pt(450, 500), 52, sides: 12) { seal.addPath(circle(p, 16)) }; seal.addPath(circle(pt(450, 500), 54))
    fill(seal, P.rose); stroke(seal, P.outline, 5)
    drawCrown(CGRect(x: 420, y: 476, width: 60, height: 46))
}

guideScene("guide_joker") {
    drawGem("sapphire", CGRect(x: 60, y: 230, width: 110, height: 110))
    drawGem("sapphire", CGRect(x: 190, y: 230, width: 110, height: 110))
    do {
        // The Joker gem art at a larger size.
        ctx.saveGState(); ctx.translateBy(x: 320, y: 220); ctx.scaleBy(x: 130 / 180, y: 130 / 180)
        drawJokerShape()
        ctx.restoreGState()
    }
    arrow(pt(480, 285), pt(560, 285))
    drawGem("sapphire", CGRect(x: 630, y: 230, width: 170, height: 170))
    drawCrown(CGRect(x: 665, y: 150, width: 100, height: 70))
    label("DROP = 2 BELLS", pt(450, 500), size: 44, color: Col(1, 0.6, 0.6))
}

guideScene("guide_jingle") {
    jesterAt(450, frame: 1, look: 1, height: 280)
    drawCap(CGRect(x: 90, y: 60, width: 200, height: 200))
    for r in [CGFloat(130), 170] { stroke(circle(pt(190, 160), r), P.tealLight.alpha(0.5), 6) }
    for (i, name) in ["topaz", "emerald"].enumerated() {
        let x = 560 + CGFloat(i) * 150
        for k in 0..<4 { fill(circle(pt(x, 150 - CGFloat(k) * 26), 34 - CGFloat(k) * 6), gemColor(name).alpha(0.12)) }
        drawGem(name, CGRect(x: x - 45, y: 150, width: 90, height: 90))
    }
    label("SLOW", pt(640, 320), size: 50, color: P.tealLight)
}

// MARK: - App icon (1024 and 512)

func drawIcon(_ size: Int) {
    begin(size, size)
    let s = CGFloat(size) / 1024
    ctx.saveGState(); ctx.scaleBy(x: s, y: s)
    let full = CGPath(rect: CGRect(x: 0, y: 0, width: 1024, height: 1024), transform: nil)
    radialFill(full, [Col(hex: 0x3A3196), Col(hex: 0x1E1858), Col(hex: 0x0E0B28)], pt(512, 470), 760)
    ctx.saveGState(); ctx.setAlpha(0.22)
    harlequin(full, Col(hex: 0x1E1858).alpha(0), Col(hex: 0x5248B8), cell: 170, bounds: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    ctx.restoreGState()
    glow(pt(512, 520), 460, P.candle.alpha(0.22))
    // Juggling arc.
    let arc = CGMutablePath(); arc.move(to: pt(210, 600)); arc.addQuadCurve(to: pt(814, 600), control: pt(512, 30))
    ctx.setLineDash(phase: 0, lengths: [14, 26]); stroke(arc, P.candle.alpha(0.75), 12); ctx.setLineDash(phase: 0, lengths: [])
    for (name, c, r) in [("sapphire", pt(250, 440), CGFloat(110)), ("ruby", pt(512, 250), CGFloat(140)), ("emerald", pt(774, 440), CGFloat(110))] {
        glow(c, r * 1.8, gemColor(name).alpha(0.45))
        drawGem(name, CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }
    // The jester's cap below.
    drawCap(CGRect(x: 262, y: 520, width: 500, height: 500))
    ctx.restoreGState()
}

do {
    let artwork = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    drawIcon(1024)
    writePNG(artwork.appendingPathComponent("JewelJuggler-1024.png"))
    let iconSet = outputRoot.deletingLastPathComponent().appendingPathComponent("AppIcon.appiconset")
    try? fm.createDirectory(at: iconSet, withIntermediateDirectories: true)
    writePNG(iconSet.appendingPathComponent("AppIcon.png"))
    try! #"{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}"#.write(to: iconSet.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    drawIcon(512)
    writePNG(artwork.appendingPathComponent("JewelJuggler-512.png"))
}
