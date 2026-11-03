
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
