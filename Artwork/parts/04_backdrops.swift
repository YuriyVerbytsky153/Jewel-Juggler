
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
