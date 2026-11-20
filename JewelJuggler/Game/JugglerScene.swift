import SpriteKit
import SwiftUI
import UIKit

@MainActor
protocol JugglerSceneDelegate: AnyObject {
    func scene(_ scene: JugglerScene, didProduce events: [RunEvent], dt: Double)
}

/// Renders the banquet hall stage and forwards touches. All rules live in `RunSession`.
final class JugglerScene: SKScene {
    private(set) var session: RunSession
    weak var showDelegate: JugglerSceneDelegate?
    var autopilot = false
    var isRunning = false {
        didSet { lastUpdate = nil }
    }

    /// Room reserved for the SwiftUI HUD above and the floor band below.
    var topInset: CGFloat = 120 { didSet { layoutStage() } }
    var bottomInset: CGFloat = 130 { didSet { layoutStage() } }

    private var lastUpdate: TimeInterval?
    private var stageRect = CGRect(x: 0, y: 130, width: 390, height: 600)
    private var gemSize: CGFloat = 46

    private let world = SKNode()
    private let backdrop = SKSpriteNode()
    private let backdropNext = SKSpriteNode()
    private let floor = SKSpriteNode(imageNamed: Art.Scene.floor)
    private let spotlight = SKSpriteNode(imageNamed: Art.Scene.spotlight)
    private let darkness = SKSpriteNode(color: UIColor(red: 0.02, green: 0.02, blue: 0.07, alpha: 1), size: .zero)
    private let jingleTint = SKSpriteNode(color: UIColor(red: 0.35, green: 0.85, blue: 0.95, alpha: 1), size: .zero)
    private let jester = SKSpriteNode()
    private let jesterShadow = SKSpriteNode(imageNamed: Art.Scene.shadow)
    private let chest = SKSpriteNode(imageNamed: Art.chestClosed)
    private let chestGlow = SKSpriteNode(imageNamed: Art.Scene.soft)
    private var gemNodes: [Int: GemNode] = [:]
    private var hallStage = 0
    private var catchPoseUntil: TimeInterval = 0
    private var petalTimer = 0.0
    private var clock: TimeInterval = 0

    private var touchStart: (point: CGPoint, time: TimeInterval)?
    private var lastTouchX: CGFloat?

    private enum Layer {
        static let backdrop: CGFloat = 0
        static let spotlight: CGFloat = 1
        static let floor: CGFloat = 2
        static let shadows: CGFloat = 3
        static let actors: CGFloat = 4
        static let darkness: CGFloat = 5
        static let gems: CGFloat = 6
        static let effects: CGFloat = 7
        static let tint: CGFloat = 8
    }

    init(session: RunSession) {
        self.session = session
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.05, green: 0.04, blue: 0.12, alpha: 1)
        anchorPoint = .zero
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Setup

    override func didMove(to view: SKView) {
        guard world.parent == nil else { return }
        addChild(world)
        backdrop.texture = SKTexture(imageNamed: Art.hall(0))
        backdrop.zPosition = Layer.backdrop
        backdropNext.zPosition = Layer.backdrop + 0.1
        backdropNext.alpha = 0
        spotlight.zPosition = Layer.spotlight
        spotlight.blendMode = .add
        spotlight.alpha = 0.55
        floor.zPosition = Layer.floor
        darkness.zPosition = Layer.darkness
        darkness.alpha = 0
        darkness.anchorPoint = .zero
        jingleTint.zPosition = Layer.tint
        jingleTint.alpha = 0
        jingleTint.blendMode = .add
        jingleTint.anchorPoint = .zero
        jester.anchorPoint = CGPoint(x: 0.5, y: 0)
        jester.zPosition = Layer.actors
        jester.texture = SKTexture(imageNamed: Art.jester(session.costume, frame: 0))
        jesterShadow.zPosition = Layer.shadows
        jesterShadow.alpha = 0.5
        chest.anchorPoint = CGPoint(x: 0.5, y: 0.08)
        chest.zPosition = Layer.actors - 0.1
        chestGlow.zPosition = Layer.actors - 0.2
        chestGlow.blendMode = .add
        chestGlow.color = UIColor(red: 1, green: 0.8, blue: 0.35, alpha: 1)
        chestGlow.colorBlendFactor = 1
        chestGlow.alpha = 0
        [backdrop, backdropNext, spotlight, floor, darkness, jingleTint, jesterShadow, jester, chestGlow, chest].forEach(world.addChild)
        layoutStage()
        syncNodes()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutStage()
    }

    private func layoutStage() {
        guard size.width > 0, size.height > 0 else { return }
        // Keep the playfield's proportions close to a phone so iPad landscape plays the same.
        let playHeight = max(200, size.height - topInset - bottomInset)
        let width = min(size.width, playHeight * 0.82)
        stageRect = CGRect(x: (size.width - width) / 2, y: bottomInset, width: width, height: playHeight)
        gemSize = min(66, max(38, width * 0.145))

        for node in [backdrop, backdropNext] {
            node.position = CGPoint(x: size.width / 2, y: size.height / 2)
            node.size = aspectFill(node.texture?.size() ?? CGSize(width: 1170, height: 2532), into: size)
        }
        floor.position = CGPoint(x: size.width / 2, y: bottomInset / 2 + 6)
        floor.size = CGSize(width: max(size.width, (floor.texture?.size().width ?? 1) * (bottomInset + 12) / max(1, floor.texture?.size().height ?? 1)), height: bottomInset + 12)
        spotlight.size = CGSize(width: width * 1.1, height: size.height * 0.95)
        spotlight.anchorPoint = CGPoint(x: 0.5, y: 0)
        spotlight.position = CGPoint(x: stageRect.midX, y: bottomInset - 20)
        darkness.size = size
        jingleTint.size = size

        let jesterHeight = RunSession.handY * playHeight * 1.06
        if let texture = jester.texture {
            let aspect = texture.size().width / max(1, texture.size().height)
            jester.size = CGSize(width: jesterHeight * aspect, height: jesterHeight)
        }
        jesterShadow.size = CGSize(width: jester.size.width * 0.9, height: jester.size.width * 0.22)
        chest.size = CGSize(width: gemSize * 1.7, height: gemSize * 1.45)
        chest.position = CGPoint(x: min(stageRect.maxX, size.width) - chest.size.width * 0.55, y: stageRect.minY)
        chestGlow.size = CGSize(width: chest.size.width * 2.2, height: chest.size.width * 2.2)
        chestGlow.position = CGPoint(x: chest.position.x, y: chest.position.y + chest.size.height * 0.4)
        for node in gemNodes.values { node.resize(gemSize) }
        syncNodes()
    }

    private func aspectFill(_ source: CGSize, into target: CGSize) -> CGSize {
        let scale = max(target.width / max(1, source.width), target.height / max(1, source.height))
        return CGSize(width: source.width * scale, height: source.height * scale)
    }

    /// Maps normalised stage coordinates to scene points.
    func point(x: Double, y: Double) -> CGPoint {
        CGPoint(x: stageRect.minX + CGFloat(x) * stageRect.width, y: stageRect.minY + CGFloat(y) * stageRect.height)
    }

    // MARK: - Commands

    func toggleBank() {
        session.toggleBank()
        updateChest()
    }

    @discardableResult
    func activateJingle() -> Bool {
        let started = session.activateJingle()
        if started {
            for node in gemNodes.values { node.sparkle() }
        }
        return started
    }

    func abandon() {
        session.abandon()
    }

    // MARK: - Loop

    override func update(_ currentTime: TimeInterval) {
        clock = currentTime
        guard isRunning else {
            lastUpdate = nil
            return
        }
        let dt = lastUpdate.map { min(0.1, currentTime - $0) } ?? 0
        lastUpdate = currentTime
        if autopilot { session.autopilot() }
        let events = session.advance(by: dt)
        for event in events { apply(event) }
        updateAtmosphere(dt)
        syncNodes()
        showDelegate?.scene(self, didProduce: events, dt: dt)
    }

    private func syncNodes() {
        let jesterPoint = point(x: session.jesterX, y: 0)
        jester.position = jesterPoint
        jesterShadow.position = CGPoint(x: jesterPoint.x, y: jesterPoint.y + 2)
        let frame = clock < catchPoseUntil ? 1 : 0
        let textureName = Art.jester(session.costume, frame: frame)
        if jester.userData?["t"] as? String != textureName {
            jester.texture = SKTexture(imageNamed: textureName)
            jester.userData = ["t": textureName]
        }

        var seen = Set<Int>()
        for gem in session.gems {
            seen.insert(gem.id)
            let node: GemNode
            if let existing = gemNodes[gem.id] {
                node = existing
            } else {
                node = GemNode(size: gemSize)
                node.zPosition = Layer.gems
                node.shadow.zPosition = Layer.shadows
                world.addChild(node)
                world.addChild(node.shadow)
                gemNodes[gem.id] = node
            }
            node.update(gem: gem, crack: session.crackStage(for: gem), glow: session.darkness > 0 || session.isJingling)
            node.position = point(x: gem.x, y: gem.y)
            let floorPoint = point(x: gem.x, y: 0)
            node.shadow.position = CGPoint(x: floorPoint.x, y: floorPoint.y + 2)
            let height = max(0, min(1, gem.y))
            node.shadow.setScale(1 - height * 0.6)
            node.shadow.alpha = 0.45 * (1 - height * 0.7)
        }
        for (id, node) in gemNodes where !seen.contains(id) {
            node.shadow.removeFromParent()
            node.removeFromParent()
            gemNodes[id] = nil
        }
        updateChest()
    }

    private func updateChest() {
        let name = session.bankArmed ? Art.chestOpen : Art.chestClosed
        if chest.userData?["t"] as? String != name {
            chest.texture = SKTexture(imageNamed: name)
            chest.userData = ["t": name]
            chestGlow.removeAllActions()
            if session.bankArmed {
                chestGlow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.8, duration: 0.35), .fadeAlpha(to: 0.4, duration: 0.35)])))
            } else {
                chestGlow.run(.fadeAlpha(to: 0, duration: 0.15))
            }
        }
    }

    private func updateAtmosphere(_ dt: Double) {
        let targetDark = CGFloat(session.darkness) * 0.92
        darkness.alpha += (targetDark - darkness.alpha) * min(1, CGFloat(dt) * 3)
        let targetTint: CGFloat = session.isJingling ? 0.14 : 0
        jingleTint.alpha += (targetTint - jingleTint.alpha) * min(1, CGFloat(dt) * 6)
        let targetSpot: CGFloat = session.isEncore ? 0.95 : 0.55 * (1 - CGFloat(session.darkness) * 0.6)
        spotlight.alpha += (targetSpot - spotlight.alpha) * min(1, CGFloat(dt) * 4)

        let stage = session.elapsed < 40 ? 0 : session.elapsed < 90 ? 1 : session.elapsed < 150 ? 2 : 3
        if stage != hallStage {
            hallStage = stage
            backdropNext.texture = SKTexture(imageNamed: Art.hall(stage))
            backdropNext.size = backdrop.size
            backdropNext.alpha = 0
            backdropNext.run(.sequence([.fadeIn(withDuration: 2.5), .run { [weak self] in
                guard let self else { return }
                self.backdrop.texture = self.backdropNext.texture
                self.backdropNext.alpha = 0
            }]))
        }

        if session.isEncore {
            petalTimer -= dt
            if petalTimer <= 0 {
                petalTimer = 0.12
                dropPetal()
            }
        }
    }

    // MARK: - Event effects

    private func apply(_ event: RunEvent) {
        switch event {
        case .caught(let id, let sweet):
            catchPoseUntil = clock + 0.16
            if sweet, let node = gemNodes[id] {
                burst(at: node.position, texture: Art.Scene.spark, color: UIColor(red: 1, green: 0.9, blue: 0.55, alpha: 1), count: 6, speed: 70, life: 0.35, scale: 0.35)
            }
        case .fused(let id, let color):
            if let node = gemNodes[id] {
                node.pop()
                burst(at: node.position, texture: Art.Scene.spark, color: UIColor(Theme.Colors.gem(color)), count: 16, speed: 150, life: 0.6, scale: 0.5)
            }
        case .banked(let gem, let points, _):
            flyToChest(gem, points: points)
        case .shattered(let gem):
            detach(gem.id)
            let p = point(x: gem.x, y: RunSession.handY)
            burst(at: p, texture: Art.Scene.shard, color: UIColor(gem.kind.color.map { Theme.Colors.gem($0) } ?? Theme.Colors.ivory), count: 14, speed: 190, life: 0.7, scale: 0.55, gravity: true)
            shake()
        case .dropped(let gem, let bells):
            let p = point(x: gem.x, y: 0)
            spawnDropped(gem, at: p)
            if bells > 0 { shake() }
        case .graceUsed(let gem):
            floatText("Grace", at: point(x: gem.x, y: 0.12), color: UIColor(Theme.Colors.ivory))
        case .tomatoCaught(let gem):
            detach(gem.id)
            burst(at: point(x: gem.x, y: RunSession.handY), texture: Art.Scene.juice, color: UIColor(red: 0.85, green: 0.2, blue: 0.12, alpha: 1), count: 14, speed: 140, life: 0.6, scale: 0.6, gravity: true)
            jester.run(.sequence([.colorize(with: .red, colorBlendFactor: 0.45, duration: 0.05), .colorize(withColorBlendFactor: 0, duration: 0.4)]))
            shake()
        case .tomatoSplat(let gem):
            detach(gem.id)
            let p = point(x: gem.x, y: 0)
            let splat = SKSpriteNode(imageNamed: Art.Scene.juice)
            splat.size = CGSize(width: gemSize * 1.3, height: gemSize * 0.45)
            splat.position = CGPoint(x: p.x, y: p.y + 2)
            splat.zPosition = Layer.shadows
            splat.color = UIColor(red: 0.75, green: 0.16, blue: 0.1, alpha: 1)
            splat.colorBlendFactor = 0.7
            world.addChild(splat)
            splat.run(.sequence([.wait(forDuration: 0.8), .fadeOut(withDuration: 0.6), .removeFromParent()]))
        case .tomatoFeast(let gem):
            detach(gem.id)
            burst(at: point(x: gem.x, y: RunSession.handY), texture: Art.Scene.juice, color: UIColor(red: 0.85, green: 0.2, blue: 0.12, alpha: 1), count: 8, speed: 90, life: 0.5, scale: 0.45, gravity: true)
            floatText("Ha!", at: point(x: gem.x, y: RunSession.handY + 0.08), color: UIColor(Theme.Colors.ivory))
        case .reborn(let gem):
            if let node = gemNodes[gem.id] {
                node.pop()
                burst(at: node.position, texture: Art.Scene.spark, color: UIColor(red: 1, green: 0.45, blue: 0.15, alpha: 1), count: 18, speed: 160, life: 0.7, scale: 0.55)
            }
        case .powderBurst(let count):
            if count > 0 {
                burst(at: CGPoint(x: stageRect.midX, y: stageRect.midY), texture: Art.Scene.spark, color: UIColor(Theme.Colors.saffron), count: 24, speed: 240, life: 0.7, scale: 0.6)
                shake()
            }
        case .encoreStarted:
            burst(at: CGPoint(x: stageRect.midX, y: stageRect.maxY - 20), texture: Art.Scene.petal, color: UIColor(Theme.Colors.rose), count: 20, speed: 160, life: 1.2, scale: 0.6, gravity: true)
        case .jingleStarted:
            for node in gemNodes.values { node.sparkle() }
        default:
            break
        }
    }

    private func detach(_ id: Int) {
        guard let node = gemNodes.removeValue(forKey: id) else { return }
        node.shadow.removeFromParent()
        node.removeFromParent()
    }

    private func flyToChest(_ gem: FlyingGem, points: Int) {
        let node: GemNode
        let start: CGPoint
        if let existing = gemNodes.removeValue(forKey: gem.id) {
            node = existing
            node.shadow.removeFromParent()
            // A Powder Garnet sweeps gems from wherever they are in the air.
            start = existing.position
        } else {
            node = GemNode(size: gemSize)
            node.update(gem: gem, crack: 0, glow: false)
            node.zPosition = Layer.gems
            world.addChild(node)
            start = point(x: gem.x, y: RunSession.handY)
        }
        node.position = start
        let end = CGPoint(x: chest.position.x, y: chest.position.y + chest.size.height * 0.5)
        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2, y: max(start.y, end.y) + stageRect.height * 0.22))
        let flight = SKAction.group([.follow(path, asOffset: false, orientToPath: false, duration: 0.45), .scale(to: 0.55, duration: 0.45)])
        flight.timingMode = .easeIn
        node.run(.sequence([flight, .run { [weak self] in
            guard let self else { return }
            self.chest.run(.sequence([.scaleY(to: 0.88, duration: 0.06), .scaleY(to: 1, duration: 0.12)]))
            self.burst(at: end, texture: Art.Scene.spark, color: UIColor(Theme.Colors.saffron), count: 8, speed: 90, life: 0.45, scale: 0.4)
        }, .removeFromParent()]))
        floatText(points > 0 ? "+\(points)" : "0", at: CGPoint(x: end.x - 10, y: end.y + 40), color: UIColor(points > 0 ? Theme.Colors.saffron : Theme.Colors.ivory))
    }

    private func spawnDropped(_ gem: FlyingGem, at p: CGPoint) {
        let node: GemNode
        if let existing = gemNodes.removeValue(forKey: gem.id) {
            node = existing
            node.shadow.removeFromParent()
        } else {
            node = GemNode(size: gemSize)
            node.update(gem: gem, crack: 3, glow: false)
            node.zPosition = Layer.gems
            world.addChild(node)
        }
        node.position = CGPoint(x: p.x, y: p.y + gemSize * 0.35)
        node.run(.sequence([
            .moveBy(x: 0, y: gemSize * 0.35, duration: 0.12),
            .moveBy(x: 0, y: -gemSize * 0.35, duration: 0.14),
            .group([.fadeOut(withDuration: 0.5), .rotate(byAngle: .pi / 3, duration: 0.5)]),
            .removeFromParent(),
        ]))
        burst(at: p, texture: Art.Scene.soft, color: UIColor(white: 0.85, alpha: 1), count: 6, speed: 50, life: 0.5, scale: 0.5)
    }

    private func dropPetal() {
        let petal = SKSpriteNode(imageNamed: Art.Scene.petal)
        let s = gemSize * CGFloat.random(in: 0.3...0.5)
        petal.size = CGSize(width: s, height: s)
        petal.position = CGPoint(x: CGFloat.random(in: stageRect.minX...stageRect.maxX), y: size.height + 10)
        petal.zPosition = Layer.effects
        petal.zRotation = CGFloat.random(in: 0...(.pi * 2))
        world.addChild(petal)
        let fall = SKAction.moveBy(x: CGFloat.random(in: -60...60), y: -(size.height - bottomInset + 20), duration: Double.random(in: 2.4...3.4))
        petal.run(.sequence([.group([fall, .rotate(byAngle: .pi * 2, duration: 3)]), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    private func burst(at p: CGPoint, texture: String, color: UIColor, count: Int, speed: CGFloat, life: Double, scale: CGFloat, gravity: Bool = false) {
        let tex = SKTexture(imageNamed: texture)
        for index in 0..<count {
            let sprite = SKSpriteNode(texture: tex)
            let s = gemSize * scale * CGFloat.random(in: 0.6...1.1)
            sprite.size = CGSize(width: s, height: s)
            sprite.position = p
            sprite.color = color
            sprite.colorBlendFactor = 0.8
            sprite.zPosition = Layer.effects
            sprite.blendMode = texture == Art.Scene.spark || texture == Art.Scene.soft ? .add : .alpha
            world.addChild(sprite)
            let angle = CGFloat(index) / CGFloat(count) * .pi * 2 + CGFloat.random(in: -0.3...0.3)
            let distance = speed * CGFloat.random(in: 0.6...1.2) * CGFloat(life)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance + (gravity ? distance * 0.2 : 0)
            var actions: [SKAction] = [.moveBy(x: dx, y: dy, duration: life), .fadeOut(withDuration: life), .rotate(byAngle: CGFloat.random(in: -3...3), duration: life)]
            if gravity { actions.append(.sequence([.wait(forDuration: life * 0.35), .moveBy(x: 0, y: -distance * 0.9, duration: life * 0.65)])) }
            sprite.run(.sequence([.group(actions), .removeFromParent()]))
        }
    }

    private func floatText(_ text: String, at p: CGPoint, color: UIColor) {
        let label = SKLabelNode(fontNamed: "Copperplate-Bold")
        label.text = text
        label.fontSize = max(18, gemSize * 0.48)
        label.fontColor = color
        label.position = p
        label.zPosition = Layer.effects
        let shadow = SKLabelNode(fontNamed: "Copperplate-Bold")
        shadow.text = text
        shadow.fontSize = label.fontSize
        shadow.fontColor = UIColor(white: 0, alpha: 0.6)
        shadow.position = CGPoint(x: 1.5, y: -1.5)
        shadow.zPosition = -0.01
        label.addChild(shadow)
        world.addChild(label)
        label.run(.sequence([.group([.moveBy(x: 0, y: 46, duration: 0.8), .sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 0.4)])]), .removeFromParent()]))
    }

    private func shake() {
        world.removeAction(forKey: "shake")
        let amount: CGFloat = 7
        let moves: [SKAction] = (0..<6).map { index in
            let direction: CGFloat = index % 2 == 0 ? 1 : -1
            let decay = CGFloat(6 - index) / CGFloat(6)
            let offset = amount * direction * decay
            return SKAction.moveTo(x: offset, duration: 0.035)
        }
        world.run(.sequence(moves + [.moveTo(x: 0, duration: 0.03)]), withKey: "shake")
    }

    // MARK: - Touches

    /// Drag anywhere to slide the jester (relative, so a tap never teleports him). A quick tap arms the chest.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let p = touch.location(in: self)
        touchStart = (p, touch.timestamp)
        lastTouchX = p.x
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isRunning, !autopilot, let touch = touches.first, let lastX = lastTouchX else { return }
        let x = touch.location(in: self).x
        let dx = Double((x - lastX) / max(1, stageRect.width)) * 1.25
        lastTouchX = x
        session.moveJester(to: session.targetX + dx)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer { touchStart = nil; lastTouchX = nil }
        guard isRunning, let touch = touches.first, let start = touchStart else { return }
        let p = touch.location(in: self)
        let moved = hypot(p.x - start.point.x, p.y - start.point.y)
        if moved < 12, touch.timestamp - start.time < 0.25 {
            session.armBank()
            updateChest()
            showDelegate?.scene(self, didProduce: [], dt: 0)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = nil
        lastTouchX = nil
    }
}

/// One gem: body sprite, crack overlay, glow halo and floor shadow.
final class GemNode: SKNode {
    let body = SKSpriteNode()
    let crack = SKSpriteNode()
    let halo = SKSpriteNode(imageNamed: Art.Scene.soft)
    let shadow = SKSpriteNode(imageNamed: Art.Scene.shadow)
    /// The enchantment's mark, set in the lower corner.
    let rune = SKSpriteNode()
    private var kind: GemKind?
    private var enchantment: Enchantment?
    private var crackStage = 0
    private var baseSize: CGFloat

    init(size: CGFloat) {
        baseSize = size
        super.init()
        halo.blendMode = .add
        halo.colorBlendFactor = 1
        halo.alpha = 0
        halo.zPosition = -0.1
        crack.zPosition = 0.1
        crack.alpha = 0
        addChild(halo)
        addChild(body)
        addChild(crack)
        rune.zPosition = 0.2
        rune.isHidden = true
        addChild(rune)
        resize(size)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func resize(_ size: CGFloat) {
        baseSize = size
        let scale: CGFloat = kind?.isCrown == true ? 1.2 : kind?.isTomato == true ? 0.9 : 1
        body.size = CGSize(width: size * scale, height: size * scale)
        crack.size = body.size
        halo.size = CGSize(width: size * 2.4, height: size * 2.4)
        rune.size = CGSize(width: size * 0.5, height: size * 0.5)
        rune.position = CGPoint(x: size * 0.32, y: -size * 0.32)
        shadow.size = CGSize(width: size * 0.9, height: size * 0.28)
    }

    func update(gem: FlyingGem, crack stage: Int, glow: Bool) {
        if kind != gem.kind {
            kind = gem.kind
            body.texture = SKTexture(imageNamed: Art.sprite(for: gem.kind))
            halo.color = gem.kind.color.map { UIColor(Theme.Colors.gem($0)) } ?? UIColor(red: 0.95, green: 0.85, blue: 0.6, alpha: 1)
            resize(baseSize)
        }
        if stage != crackStage {
            crackStage = stage
            if stage > 0 {
                crack.texture = SKTexture(imageNamed: Art.crack(stage))
                crack.alpha = 1
                if stage == 3 {
                    crack.run(.repeatForever(.sequence([.fadeAlpha(to: 0.55, duration: 0.18), .fadeAlpha(to: 1, duration: 0.18)])), withKey: "pulse")
                }
            } else {
                crack.removeAction(forKey: "pulse")
                crack.alpha = 0
            }
        }
        if enchantment != gem.enchantment {
            enchantment = gem.enchantment
            if let enchantment = gem.enchantment {
                rune.texture = Self.runeTexture(for: enchantment)
                rune.isHidden = false
                halo.color = UIColor(Theme.Colors.candle)
            } else {
                rune.isHidden = true
            }
        }
        let targetHalo: CGFloat = gem.kind.isTomato ? 0 : glow ? 0.85 : gem.enchantment != nil ? 0.6 : 0.22
        halo.alpha += (targetHalo - halo.alpha) * 0.15
        body.zRotation = CGFloat(gem.vx) * 0.6
    }

    private static var runeTextures: [Enchantment: SKTexture] = [:]

    /// The enchantment's symbol on a small dark disc, drawn once and shared.
    private static func runeTexture(for enchantment: Enchantment) -> SKTexture {
        if let cached = runeTextures[enchantment] { return cached }
        let side: CGFloat = 64
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            let disc = UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: side - 4, height: side - 4))
            UIColor(Theme.Colors.velvetDeep).setFill()
            disc.fill()
            UIColor(Theme.Colors.saffron).setStroke()
            disc.lineWidth = 3
            disc.stroke()
            let config = UIImage.SymbolConfiguration(pointSize: side * 0.42, weight: .bold)
            if let symbol = UIImage(systemName: enchantment.symbol, withConfiguration: config)?.withTintColor(UIColor(Theme.Colors.ivory), renderingMode: .alwaysOriginal) {
                let size = symbol.size
                symbol.draw(in: CGRect(x: (side - size.width) / 2, y: (side - size.height) / 2, width: size.width, height: size.height))
            }
        }
        let texture = SKTexture(image: image)
        runeTextures[enchantment] = texture
        return texture
    }

    func pop() {
        run(.sequence([.scale(to: 1.4, duration: 0.08), .scale(to: 1, duration: 0.18)]))
    }

    func sparkle() {
        halo.run(.sequence([.fadeAlpha(to: 1, duration: 0.1), .fadeAlpha(to: 0.4, duration: 0.6)]))
    }
}
