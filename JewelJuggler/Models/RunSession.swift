import Foundation

/// Something that happened during a simulation step, for the scene, sounds and HUD.
enum RunEvent: Equatable, Sendable {
    case spawned(id: Int)
    case caught(id: Int, sweet: Bool)
    case fused(id: Int, color: GemColor)
    case banked(gem: FlyingGem, points: Int, ducats: Int)
    case shattered(gem: FlyingGem)
    case dropped(gem: FlyingGem, bells: Int)
    case graceUsed(gem: FlyingGem)
    case tomatoCaught(gem: FlyingGem)
    case tomatoSplat(gem: FlyingGem)
    case encoreStarted
    case encoreEnded
    case decreeWarning(Decree)
    case decreeStarted(Decree)
    case decreeEnded(Decree)
    case jingleReady
    case jingleStarted
    case jingleEnded
    case goalCompleted
    case curtain
}

/// How a show ended.
enum RunResult: String, Codable, Sendable {
    /// All bells lost.
    case bellsOut
    /// The act's goal was reached.
    case goalComplete
    /// The player left from the pause menu.
    case abandoned
}

/// The decree scroll state.
enum DecreeState: Equatable, Sendable {
    case none
    case warning(Decree, remaining: Double)
    case active(Decree, remaining: Double)

    var decree: Decree? {
        switch self {
        case .none: nil
        case .warning(let d, _), .active(let d, _): d
        }
    }

    var activeDecree: Decree? {
        if case .active(let d, _) = self { return d }
        return nil
    }
}

/// The final tally of one show.
struct RunSummary: Equatable, Sendable {
    let mode: RunMode
    let costume: Costume
    let result: RunResult
    let score: Int
    let ducats: Int
    let banks: Int
    let crowns: Int
    let encores: Int
    let decrees: Int
    let jokers: Int
    let maxAirborne: Int
    let catches: Int
    let sweetCatches: Int
    let bellsLost: Int
    let tomatoesDodged: Int
    let seconds: Int
    let roses: Int
}

/// The rules of one show, free of any UI framework so they can be unit tested.
///
/// Coordinates are normalised: x runs 0...1 across the stage, y runs 0...1 from the floor to the top.
/// The scene renders this state and forwards touches; the session decides everything else.
struct RunSession {
    // MARK: Constants

    static let handY = 0.24
    static let floorY = 0.015
    static let spawnY = 1.04
    static let wallInset = 0.04
    static let fixedStep = 1.0 / 120
    static let jesterSpeed = 1.6
    static let sweetSpotFraction = 0.38
    static let jingleDuration = 3.0
    static let jingleTimeScale = 0.45
    static let decreeDuration = 10.0
    static let decreeWarning = 3.0
    static let spawnInterval = 1.5
    static let tomatoInterval = 1.25

    // MARK: Setup

    let setup: RunSetup
    let config: RunConfig
    let loadout: Loadout
    var costume: Costume { loadout.costume }
    /// UI tests: bells never fall below one.
    var isInvincible = false

    // MARK: State

    private(set) var gems: [FlyingGem] = []
    private(set) var jesterX = 0.5
    private(set) var targetX = 0.5
    /// The next catch goes into the chest instead of back into the air.
    private(set) var bankArmed = false

    private(set) var bells: Int
    private(set) var bellsLost = 0
    private(set) var graceUsed = false
    private(set) var score = 0
    private(set) var ducats = 0
    private(set) var banks = 0
    private(set) var crownsFused = 0
    private(set) var encores = 0
    private(set) var decreesWeathered = 0
    private(set) var jokersBanked = 0
    private(set) var catches = 0
    private(set) var sweetCatches = 0
    private(set) var tomatoesDodged = 0
    private(set) var cleanStreak = 0
    private(set) var bestCleanStreak = 0
    private(set) var maxAirborne = 0
    private(set) var elapsed = 0.0

    /// Court Applause, 0...1. Full starts an Encore.
    private(set) var applause = 0.0
    private(set) var encoreTime = 0.0
    private(set) var decree: DecreeState = .none
    private(set) var nextDecreeAt: Double

    /// Chord in progress: colour and how many matching catches it has.
    private(set) var chordColor: GemColor?
    private(set) var chordCount = 0

    private(set) var jingleCharge = 0
    private(set) var jingleTime = 0.0

    private(set) var result: RunResult?
    private var nextID = 1
    private var spawnTimer = 1.2
    private var tomatoTimer = 0.6
    private var lastDecree: Decree?
    private var accumulator = 0.0
    private var rng: SeededGenerator

    init(setup: RunSetup) {
        self.setup = setup
        config = setup.config
        loadout = setup.loadout
        bells = setup.loadout.bells
        rng = SeededGenerator(seed: setup.seed)
        nextDecreeAt = 20
    }

    // MARK: Derived

    var isOver: Bool { result != nil }
    var isEncore: Bool { encoreTime > 0 }
    var isJingling: Bool { jingleTime > 0 }
    var isJingleReady: Bool { !isJingling && jingleCharge >= loadout.jingleCharges }
    var jingleFraction: Double { isJingling ? jingleTime / Self.jingleDuration : min(1, Double(jingleCharge) / Double(loadout.jingleCharges)) }
    var encoreFraction: Double { isEncore ? encoreTime / loadout.encoreDuration : 0 }
    var airborne: Int { gems.filter { !$0.kind.isTomato }.count }
    var catchHalfWidth: Double { loadout.catchHalfWidth }
    /// Gentle warm-up: gems fall slower for the first 20 seconds, then speed up slowly.
    var gravity: Double {
        elapsed < 20 ? 0.8 + elapsed * 0.01 : min(1.45, 1.0 + (elapsed - 20) * 0.0035)
    }
    var maxBells: Int { loadout.bells }

    /// How dark the hall is right now (Candle Gust), 0...1.
    var darkness: Double { decree.activeDecree == .candleGust ? loadout.gustDarkness : 0 }

    /// How many gems the court wants in the air right now.
    var desiredGems: Int {
        let base = min(config.maxGems, 1 + Int(elapsed / 15))
        return base + (isEncore ? 1 : 0)
    }

    /// Colours in play: three at first, all five after a minute.
    var colorsInPlay: [GemColor] {
        let count = elapsed < 30 ? 3 : elapsed < 60 ? 4 : 5
        return Array(GemColor.allCases.prefix(count))
    }

    func tossLimit(for gem: FlyingGem) -> Int {
        loadout.tossLimit + costume.extraTosses(for: gem.kind)
    }

    /// 0...3 crack stage for rendering. Stage 3 means the next toss shatters it.
    func crackStage(for gem: FlyingGem) -> Int {
        guard !gem.kind.isTomato else { return 0 }
        let limit = tossLimit(for: gem)
        if gem.tosses >= limit { return 3 }
        return min(2, gem.tosses * 3 / limit)
    }

    /// Progress towards the act goal (nil for endless shows).
    var goalProgress: Int? {
        guard let goal = config.goal else { return nil }
        switch goal {
        case .bank: return banks
        case .crowns: return crownsFused
        case .airborne: return maxAirborne
        case .cleanBanks: return bestCleanStreak
        case .decrees: return decreesWeathered
        case .encores: return encores
        case .jokers: return jokersBanked
        case .survive: return Int(elapsed)
        case .score: return score
        }
    }

    /// Roses for an act: three without losing a bell, two for at most one, one otherwise.
    var roses: Int {
        guard result == .goalComplete else { return 0 }
        return bellsLost == 0 ? 3 : bellsLost <= 1 ? 2 : 1
    }

    var summary: RunSummary {
        RunSummary(mode: setup.mode, costume: costume, result: result ?? .abandoned, score: score, ducats: ducats,
                   banks: banks, crowns: crownsFused, encores: encores, decrees: decreesWeathered, jokers: jokersBanked,
                   maxAirborne: maxAirborne, catches: catches, sweetCatches: sweetCatches, bellsLost: bellsLost,
                   tomatoesDodged: tomatoesDodged, seconds: Int(elapsed), roses: roses)
    }

    // MARK: Input

    mutating func moveJester(to x: Double) {
        targetX = min(1 - Self.wallInset, max(Self.wallInset, x))
    }

    /// Toggles whether the next catch is banked.
    mutating func toggleBank() {
        guard !isOver else { return }
        bankArmed.toggle()
    }

    mutating func armBank() {
        guard !isOver else { return }
        bankArmed = true
    }

    /// Slows the gems for a moment. Returns false if the Jingle is not charged.
    @discardableResult
    mutating func activateJingle() -> Bool {
        guard isJingleReady, !isOver else { return false }
        jingleCharge = 0
        jingleTime = Self.jingleDuration
        return true
    }

    mutating func abandon() {
        guard result == nil else { return }
        result = .abandoned
    }

    // MARK: Simulation

    /// Advances the show by `dt` seconds of wall time using fixed sub-steps.
    mutating func advance(by dt: Double) -> [RunEvent] {
        guard !isOver else { return [] }
        // The scene already caps a frame's dt; tests may advance several seconds at once.
        accumulator += max(0, dt)
        var events: [RunEvent] = []
        while accumulator >= Self.fixedStep, !isOver {
            accumulator -= Self.fixedStep
            step(Self.fixedStep, into: &events)
        }
        return events
    }

    /// Exactly one fixed step; exposed for tests.
    mutating func step(_ dt: Double, into events: inout [RunEvent]) {
        guard !isOver else { return }
        elapsed += dt
        moveJesterTowardsTarget(dt)
        updateTimers(dt, &events)
        guard !isOver else { return }

        let gemDt = isJingling ? dt * Self.jingleTimeScale : dt
        spawnIfNeeded(gemDt, &events)
        moveGems(gemDt, &events)
        guard !isOver else { return }

        maxAirborne = max(maxAirborne, airborne)
        if !isEncore {
            applause += dt * 0.022 * Double(max(0, airborne - 1))
            if applause >= 1 { startEncore(&events) }
        }
        checkGoal(&events)
    }

    private mutating func moveJesterTowardsTarget(_ dt: Double) {
        let maxMove = Self.jesterSpeed * costume.speedMultiplier * dt
        let delta = targetX - jesterX
        jesterX += max(-maxMove, min(maxMove, delta))
    }

    private mutating func updateTimers(_ dt: Double, _ events: inout [RunEvent]) {
        if isEncore {
            encoreTime -= dt
            if encoreTime <= 0 {
                encoreTime = 0
                events.append(.encoreEnded)
            }
        }
        if isJingling {
            jingleTime -= dt
            if jingleTime <= 0 {
                jingleTime = 0
                events.append(.jingleEnded)
            }
        }
        updateDecree(dt, &events)
    }

    private mutating func updateDecree(_ dt: Double, _ events: inout [RunEvent]) {
        guard !config.decrees.isEmpty else { return }
        switch decree {
        case .none:
            if elapsed >= nextDecreeAt {
                let pool = config.decrees.count > 1 ? config.decrees.filter { $0 != lastDecree } : config.decrees
                let chosen = pool[Int(rng.next() % UInt64(pool.count))]
                lastDecree = chosen
                decree = .warning(chosen, remaining: Self.decreeWarning + costume.decreeWarningBonus)
                events.append(.decreeWarning(chosen))
            }
        case .warning(let d, let remaining):
            let left = remaining - dt
            if left <= 0 {
                decree = .active(d, remaining: Self.decreeDuration)
                tomatoTimer = 0.5
                events.append(.decreeStarted(d))
            } else {
                decree = .warning(d, remaining: left)
            }
        case .active(let d, let remaining):
            let left = remaining - dt
            if left <= 0 {
                decree = .none
                decreesWeathered += 1
                nextDecreeAt = elapsed + rng.value(in: 14...20)
                events.append(.decreeEnded(d))
            } else {
                decree = .active(d, remaining: left)
            }
        }
    }

    private mutating func spawnIfNeeded(_ dt: Double, _ events: inout [RunEvent]) {
        spawnTimer -= dt
        if spawnTimer <= 0, airborne < desiredGems {
            spawnTimer = Self.spawnInterval
            spawnGem(&events)
        }
        if decree.activeDecree == .rottenTomatoes {
            tomatoTimer -= dt
            if tomatoTimer <= 0 {
                tomatoTimer = Self.tomatoInterval
                spawn(kind: .tomato, &events)
            }
        }
    }

    private mutating func spawnGem(_ events: inout [RunEvent], gift: Bool = false) {
        let jokerChance = config.jokers && elapsed > 20 ? 0.07 * costume.jokerChanceMultiplier : 0
        let kind: GemKind
        if rng.unit() < jokerChance {
            kind = .joker
        } else {
            let palette = colorsInPlay
            kind = .plain(palette[Int(rng.next() % UInt64(palette.count))])
        }
        spawn(kind: kind, gift: gift, &events)
    }

    private mutating func spawn(kind: GemKind, gift: Bool = false, _ events: inout [RunEvent]) {
        // Keep new drops away from the jester's hands so each one asks for a move.
        var x = rng.value(in: 0.14...0.86)
        if abs(x - jesterX) < 0.12 { x = x < 0.5 ? x + 0.3 : x - 0.3 }
        let gem = FlyingGem(id: nextID, kind: kind, x: x, y: Self.spawnY,
                            vx: rng.value(in: -0.05...0.05), vy: kind.isTomato ? -0.25 : -0.05, isEncoreGift: gift)
        nextID += 1
        gems.append(gem)
        events.append(.spawned(id: gem.id))
    }

    private mutating func moveGems(_ dt: Double, _ events: inout [RunEvent]) {
        var index = 0
        while index < gems.count {
            var gem = gems[index]
            let previousY = gem.y
            gem.vy -= gravity * gem.kind.gravityScale * dt
            gem.x += gem.vx * dt
            gem.y += gem.vy * dt
            if gem.x < Self.wallInset { gem.x = Self.wallInset; gem.vx = abs(gem.vx) }
            if gem.x > 1 - Self.wallInset { gem.x = 1 - Self.wallInset; gem.vx = -abs(gem.vx) }
            gems[index] = gem

            if gem.isFalling, previousY >= Self.handY, gem.y < Self.handY, abs(gem.x - jesterX) <= catchHalfWidth {
                if handleCatch(at: index, &events) { index += 1 }
                if isOver { return }
                continue
            }
            if gem.y <= Self.floorY {
                gems.remove(at: index)
                handleFloor(gem, &events)
                if isOver { return }
                continue
            }
            index += 1
        }
    }

    /// Returns true if the gem stays in the air (tossed), false if it was removed.
    private mutating func handleCatch(at index: Int, _ events: inout [RunEvent]) -> Bool {
        var gem = gems[index]
        if gem.kind.isTomato {
            gems.remove(at: index)
            events.append(.tomatoCaught(gem: gem))
            loseBells(1, &events)
            return false
        }

        let sweet = abs(gem.x - jesterX) <= catchHalfWidth * Self.sweetSpotFraction
        catches += 1
        events.append(.caught(id: gem.id, sweet: sweet))
        if sweet {
            sweetCatches += 1
            if !isJingling, jingleCharge < loadout.jingleCharges {
                jingleCharge += 1
                if jingleCharge == loadout.jingleCharges { events.append(.jingleReady) }
            }
        }
        if !isEncore { applause = min(1, applause + 0.012) }
        score += points(base: 1 * max(1, airborne), for: gem.kind)

        if let color = advanceChord(with: gem.kind) {
            gem.kind = .crown(color)
            gem.tosses = 0
            crownsFused += 1
            events.append(.fused(id: gem.id, color: color))
        }

        if bankArmed {
            bankArmed = false
            gems.remove(at: index)
            bank(gem, &events)
            return false
        }

        if gem.tosses >= tossLimit(for: gem) {
            gems.remove(at: index)
            events.append(.shattered(gem: gem))
            cleanStreak = 0
            loseBells(1, &events)
            return false
        }

        toss(&gem)
        gems[index] = gem
        return true
    }

    /// Feeds a catch into the chord. Returns the colour to fuse into when the chord completes.
    private mutating func advanceChord(with kind: GemKind) -> GemColor? {
        switch kind {
        case .plain(let color):
            let weight = costume.chordWeight(for: color)
            if chordColor == nil || chordColor == color {
                chordCount += weight
            } else {
                chordCount = weight
            }
            chordColor = color
        case .joker:
            chordCount += 1
        case .crown, .tomato:
            return nil
        }
        guard chordCount >= 3, let color = chordColor else { return nil }
        chordCount = 0
        chordColor = nil
        return color
    }

    private mutating func toss(_ gem: inout FlyingGem) {
        gem.tosses += 1
        let apex = rng.value(in: 0.62...0.86)
        let g = gravity * gem.kind.gravityScale
        let height = apex - Self.handY
        gem.vy = (2 * g * height).squareRoot()
        let flight = 2 * gem.vy / g
        var target = rng.value(in: 0.12...0.88)
        if abs(target - gem.x) < 0.15 { target = gem.x < 0.5 ? gem.x + 0.25 : gem.x - 0.25 }
        gem.vx = (target - gem.x) / flight
        gem.y = Self.handY
    }

    private mutating func bank(_ gem: FlyingGem, _ events: inout [RunEvent]) {
        let wearBonus = 1 + 0.5 * Double(gem.tosses)
        let pts = points(base: Int(Double(gem.kind.bankValue) * wearBonus), for: gem.kind)
        let baseDucats = Double(gem.kind.bankValue) / 5 * (1 + 0.25 * Double(gem.tosses))
        let coins = Int((baseDucats * Double(costume.ducatMultiplier(for: gem.kind)) * config.ducatMultiplier).rounded())
        score += pts
        ducats += coins
        banks += 1
        cleanStreak += 1
        bestCleanStreak = max(bestCleanStreak, cleanStreak)
        if gem.kind.isJoker { jokersBanked += 1 }
        events.append(.banked(gem: gem, points: pts, ducats: coins))
    }

    /// Applies Encore, Candle Gust and Ruby Hour to a number of points.
    func points(base: Int, for kind: GemKind) -> Int {
        var value = Double(base)
        if isEncore { value *= 2 }
        switch decree.activeDecree {
        case .rubyHour: value *= kind.color == .ruby ? 3 : 0
        case .candleGust: value *= costume.gustMultiplier
        default: break
        }
        return Int(value.rounded())
    }

    private mutating func handleFloor(_ gem: FlyingGem, _ events: inout [RunEvent]) {
        if gem.kind.isTomato {
            tomatoesDodged += 1
            events.append(.tomatoSplat(gem: gem))
            return
        }
        cleanStreak = 0
        applause = max(0, applause - 0.25)
        var cost = gem.kind.dropCost(costume: costume)
        if loadout.hasGrace, !graceUsed {
            graceUsed = true
            cost = 0
            events.append(.graceUsed(gem: gem))
        }
        events.append(.dropped(gem: gem, bells: cost))
        loseBells(cost, &events)
    }

    private mutating func loseBells(_ count: Int, _ events: inout [RunEvent]) {
        guard count > 0 else { return }
        cleanStreak = 0
        let lost = isInvincible ? min(count, max(0, bells - 1)) : min(count, bells)
        bells -= lost
        bellsLost += lost
        if bells <= 0 {
            result = .bellsOut
            events.append(.curtain)
        }
    }

    private mutating func startEncore(_ events: inout [RunEvent]) {
        applause = 0
        encores += 1
        encoreTime = loadout.encoreDuration
        events.append(.encoreStarted)
        // The king tosses one more gem onto the stage to celebrate.
        spawnGem(&events, gift: true)
    }

    private mutating func checkGoal(_ events: inout [RunEvent]) {
        guard let goal = config.goal, let progress = goalProgress, progress >= goal.target else { return }
        result = .goalComplete
        events.append(.goalCompleted)
    }

    // MARK: Autopilot

    /// A simple performer used by UI tests and screenshot tours: chase the gem that lands first,
    /// avoid tomatoes and bank anything about to crack.
    mutating func autopilot() {
        let incoming = gems.filter { !$0.kind.isTomato }.compactMap { gem -> (FlyingGem, Double)? in
            guard let t = timeToHands(gem) else { return nil }
            return (gem, t)
        }.sorted { $0.1 < $1.1 }
        guard let (next, _) = incoming.first else {
            moveJester(to: 0.5)
            return
        }
        let landing = next.x + next.vx * (timeToHands(next) ?? 0)
        var target = min(1 - Self.wallInset, max(Self.wallInset, landing))
        // Step aside from a tomato heading for the same spot.
        if gems.contains(where: { $0.kind.isTomato && abs(($0.x + $0.vx * (timeToHands($0) ?? 0)) - target) < catchHalfWidth * 1.2 && (timeToHands($0) ?? 9) < 0.5 }) {
            target += target < 0.5 ? catchHalfWidth * 0.9 : -catchHalfWidth * 0.9
        }
        moveJester(to: target)
        let wantsBank = next.tosses >= tossLimit(for: next) || next.kind.isCrown || next.kind.isJoker || next.tosses >= 2
        if wantsBank != bankArmed { bankArmed = wantsBank }
        if isJingleReady, incoming.count >= 3 { activateJingle() }
    }

    /// Seconds until a gem falls through the hands' height, or nil if it never will.
    func timeToHands(_ gem: FlyingGem) -> Double? {
        let g = gravity * gem.kind.gravityScale
        let dy = gem.y - Self.handY
        // Solve y + vy t - g t²/2 = handY for the later root.
        let disc = gem.vy * gem.vy + 2 * g * dy
        guard disc >= 0 else { return nil }
        let t = (gem.vy + disc.squareRoot()) / g
        return t >= 0 ? t * (isJingling ? 1 / Self.jingleTimeScale : 1) : nil
    }

    // MARK: Test hooks

    /// Places a gem directly (unit tests).
    @discardableResult
    mutating func insertForTesting(_ kind: GemKind, x: Double, y: Double, vx: Double = 0, vy: Double = 0, tosses: Int = 0) -> Int {
        let gem = FlyingGem(id: nextID, kind: kind, x: x, y: y, vx: vx, vy: vy, tosses: tosses)
        nextID += 1
        gems.append(gem)
        return gem.id
    }

    /// Stops automatic spawning and decrees so tests control every object.
    mutating func freezeSpawningForTesting() {
        spawnTimer = .infinity
        nextDecreeAt = .infinity
    }

    mutating func setJesterForTesting(_ x: Double) {
        jesterX = x
        targetX = x
    }

    mutating func setApplauseForTesting(_ value: Double) { applause = value }
    mutating func setElapsedForTesting(_ value: Double) { elapsed = value }
    mutating func scheduleDecreeForTesting(at time: Double) { nextDecreeAt = time }
}
