
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
