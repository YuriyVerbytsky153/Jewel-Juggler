
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
