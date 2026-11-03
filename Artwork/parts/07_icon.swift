
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
