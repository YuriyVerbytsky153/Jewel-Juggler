
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
