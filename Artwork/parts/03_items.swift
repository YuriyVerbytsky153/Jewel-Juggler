
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
