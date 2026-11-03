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
