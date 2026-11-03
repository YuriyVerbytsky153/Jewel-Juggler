import SpriteKit
import SwiftUI

/// The show: SpriteKit stage under a SwiftUI HUD, with the playbill, pause and Curtain Call overlays.
struct GameView: View {
    @State private var viewModel: GameViewModel
    let onExit: () -> Void
    @Environment(\.calmDecor) private var calm
    @State private var topHeight: CGFloat = 120
    @State private var bottomHeight: CGFloat = 130

    init(viewModel: GameViewModel, onExit: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onExit = onExit
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Theme.Colors.velvetDeep.ignoresSafeArea()
                if let scene = viewModel.scene {
                    SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                        .id(viewModel.sceneID)
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                }

                VStack(spacing: 0) {
                    ShowTopBar(viewModel: viewModel)
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { topHeight = $0 }
                    if viewModel.hud.decree != .none {
                        DecreeScroll(state: viewModel.hud.decree)
                            .padding(.horizontal, 12)
                            .padding(.top, 6)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer(minLength: 0)
                    ShowBottomBar(viewModel: viewModel)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bottomHeight = $0 + proxy.safeAreaInsets.bottom }
                }
                .opacity(viewModel.phase.showsHUD ? 1 : 0)
                .accessibilityHidden(!viewModel.phase.showsHUD || viewModel.phase == .paused)
                .animation(.spring(duration: 0.4), value: viewModel.hud.decree.decree)

                if let callout = viewModel.callout, viewModel.phase == .running {
                    CalloutView(callout: callout)
                        .id(callout.id)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                        .padding(.top, topHeight + 6)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .allowsHitTesting(false)
                }

                overlay
            }
            .onAppear {
                viewModel.prepareScene()
                updateInsets(proxy)
            }
            .onChange(of: topHeight) { updateInsets(proxy) }
            .onChange(of: bottomHeight) { updateInsets(proxy) }
            .onChange(of: viewModel.sceneID) { updateInsets(proxy) }
        }
        .animation(.spring(duration: 0.35), value: viewModel.callout)
        .animation(.easeInOut(duration: 0.3), value: viewModel.phase)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Game.screen)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    private func updateInsets(_ proxy: GeometryProxy) {
        // The scene ignores the safe area: the top bar is measured in global (full-screen) coordinates.
        viewModel.scene?.topInset = topHeight + 12
        viewModel.scene?.bottomInset = bottomHeight
    }

    @ViewBuilder
    private var overlay: some View {
        switch viewModel.phase {
        case .ready:
            PlaybillCard(viewModel: viewModel, onLeave: { viewModel.leave(); onExit() })
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .countdown(let value):
            Text("\(value)")
                .font(.engraved(110, relativeTo: .largeTitle))
                .foregroundStyle(Theme.Colors.saffron)
                .shadow(color: .black.opacity(0.6), radius: 10, y: 4)
                .id(value)
                .transition(.scale(scale: 1.6).combined(with: .opacity))
                .accessibilityLabel("Starting in \(value)")
                .allowsHitTesting(false)
        case .paused:
            PauseCard(viewModel: viewModel, onLeave: { viewModel.leave(); onExit() })
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        case .finished(let outcome):
            CurtainCallView(outcome: outcome, viewModel: viewModel, onLeave: { viewModel.leave(); onExit() })
                .transition(.opacity)
        case .running, .ending:
            EmptyView()
        }
    }
}

extension GameViewModel.Phase {
    var showsHUD: Bool {
        switch self {
        case .running, .countdown, .paused, .ending: true
        case .ready, .finished: false
        }
    }
}

// MARK: - Top HUD

/// Pause medallion, cap of bells, score ribbon, chord sockets and the decree scroll.
struct ShowTopBar: View {
    let viewModel: GameViewModel

    var body: some View {
        let hud = viewModel.hud
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                MedallionButton(image: Art.Medallion.pause, label: "Pause", size: 44) { viewModel.pause() }
                    .accessibilityIdentifier(AccessibilityID.Game.pause)
                Spacer(minLength: 0)
                ScoreRibbon(score: hud.score, isEncore: hud.isEncore)
                Spacer(minLength: 0)
                BellCap(bells: hud.bells, maxBells: hud.maxBells, hasGrace: hud.hasGrace, shake: viewModel.bellShake)
            }
            HStack(alignment: .top, spacing: 8) {
                ChordSockets(color: hud.chordColor, count: hud.chordCount)
                Spacer(minLength: 0)
                if let goal = viewModel.goal {
                    GoalChip(goal: goal, progress: hud.goalProgress ?? 0)
                } else {
                    DucatBadge(amount: hud.ducats, compact: true)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .frame(maxWidth: Theme.Metrics.maxContentWidth)
    }
}

struct ScoreRibbon: View {
    let score: Int
    let isEncore: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text(Formatters.integer(score))
                .font(.engraved(26, relativeTo: .title))
                .foregroundStyle(Theme.Colors.ink)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(score)))
            if isEncore {
                Text("Encore ×2")
                    .font(.court(.caption2, weight: .bold))
                    .foregroundStyle(Theme.Colors.rose)
            }
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 6)
        .frame(minWidth: 140)
        .background {
            Image(Art.Panel.ribbon)
                .resizable(capInsets: PanelInsets.ribbon, resizingMode: .stretch)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(score)")
        .accessibilityValue("\(score)")
        .accessibilityIdentifier(AccessibilityID.Game.score)
    }
}

/// The jester's cap: one bell per life.
struct BellCap: View {
    let bells: Int
    let maxBells: Int
    let hasGrace: Bool
    let shake: Int

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<maxBells, id: \.self) { index in
                Image(index < bells ? Art.bellOn : Art.bellOff)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
            }
            if hasGrace {
                Image(systemName: "sparkle")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.Colors.ivory)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.Colors.velvetDeep.opacity(0.85)))
        .overlay(Capsule().strokeBorder(Theme.Colors.gold.opacity(0.8), lineWidth: 1.5))
        .keyframeAnimator(initialValue: 0.0, trigger: shake) { content, offset in
            content.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-8, duration: 0.06)
                CubicKeyframe(8, duration: 0.08)
                CubicKeyframe(-4, duration: 0.08)
                CubicKeyframe(0, duration: 0.1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(bells) of \(maxBells) bells")
        .accessibilityValue("\(bells)")
        .accessibilityIdentifier(AccessibilityID.Game.bells)
    }
}

/// Three sockets that fill with matching catches; the third fuses a Crown Gem.
struct ChordSockets: View {
    let color: GemColor?
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Text("Chord")
                .font(.court(.caption, weight: .bold))
                .foregroundStyle(Theme.Colors.ivory)
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.velvetDeep)
                            .overlay(Circle().strokeBorder(Theme.Colors.gold.opacity(0.7), lineWidth: 1.5))
                        if index < count {
                            Image(color.map(Art.gem) ?? Art.joker)
                                .resizable()
                                .scaledToFit()
                                .padding(3)
                                .transition(.scale)
                        }
                    }
                    .frame(width: 26, height: 26)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(Theme.Colors.velvetDeep.opacity(0.85)))
        .animation(.spring(duration: 0.25), value: count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(color.map { "Chord: \(count) of 3 \($0.title)" } ?? "Chord: \(count) of 3")
        .accessibilityIdentifier(AccessibilityID.Game.chord)
    }
}

struct GoalChip: View {
    let goal: ActGoal
    let progress: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(Art.rose)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
            Text(goal.text)
                .font(.court(.caption, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text("\(min(progress, goal.target))/\(goal.target)")
                .font(.engraved(14, relativeTo: .caption))
                .monospacedDigit()
        }
        .foregroundStyle(Theme.Colors.ivory)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.Colors.velvetDeep.opacity(0.85)))
        .overlay(Capsule().strokeBorder(Theme.Colors.rose.opacity(0.8), lineWidth: 1.5))
        .frame(maxWidth: 230, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Goal: \(goal.text), \(progress) of \(goal.target)")
        .accessibilityIdentifier(AccessibilityID.Game.goal)
    }
}

/// The king's decree, unrolled under the HUD while it is announced and in force.
struct DecreeScroll: View {
    let state: DecreeState

    var body: some View {
        if let decree = state.decree {
            let isWarning: Bool = { if case .warning = state { return true } else { return false } }()
            let remaining: Double = {
                switch state {
                case .warning(_, let r), .active(_, let r): r
                case .none: 0
                }
            }()
            if !isWarning {
                // While in force the decree shrinks to a small chip so it never hides falling gems.
                HStack(spacing: 6) {
                    Image(Art.decree(decree)).resizable().scaledToFit().frame(width: 24, height: 24)
                    Text(decree.title).font(.engraved(13, relativeTo: .caption))
                    Text(String(format: "%.0f", remaining.rounded(.up)))
                        .font(.engraved(13, relativeTo: .caption))
                        .foregroundStyle(Theme.Colors.saffron)
                        .monospacedDigit()
                }
                .foregroundStyle(Theme.Colors.ivory)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.Colors.velvetDeep.opacity(0.88)))
                .overlay(Capsule().strokeBorder(Theme.Colors.saffron.opacity(0.8), lineWidth: 1.5))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Decree: \(decree.title). \(decree.instruction)")
                .accessibilityIdentifier(AccessibilityID.Game.decree)
            } else {
            HStack(spacing: 10) {
                Image(Art.decree(decree))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text("By royal decree, soon: \(decree.title)")
                        .font(.engraved(15, relativeTo: .headline))
                    Text(decree.instruction)
                        .font(.court(.caption, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Theme.Colors.ink)
                Spacer(minLength: 0)
                Text(String(format: "%.0f", remaining.rounded(.up)))
                    .font(.engraved(20, relativeTo: .title3))
                    .foregroundStyle(Theme.Colors.rose)
                    .monospacedDigit()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
            .frame(maxWidth: 520)
            .background {
                Image(Art.Panel.scroll)
                    .resizable(capInsets: PanelInsets.scroll, resizingMode: .stretch)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Coming decree: \(decree.title). \(decree.instruction)")
            .accessibilityIdentifier(AccessibilityID.Game.decree)
            }
        }
    }
}

// MARK: - Bottom HUD

/// Audience silhouettes that light up with applause, flanked by the JINGLE and BANK buttons.
struct ShowBottomBar: View {
    let viewModel: GameViewModel

    var body: some View {
        let hud = viewModel.hud
        let jingle = JingleButton(fraction: hud.jingleFraction, isReady: hud.isJingleReady, isActive: hud.isJingling) { viewModel.jingleTapped() }
        let bank = BankButton(isArmed: hud.bankArmed) { viewModel.bankTapped() }
        VStack(spacing: 4) {
            ApplauseCrowd(fraction: hud.isEncore ? hud.encoreFraction : hud.applause, isEncore: hud.isEncore)
            HStack(alignment: .bottom) {
                if viewModel.settings.leftHanded { bank } else { jingle }
                Spacer()
                if viewModel.settings.leftHanded { jingle } else { bank }
            }
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 6)
        .frame(maxWidth: Theme.Metrics.maxContentWidth)
    }
}

struct ApplauseCrowd: View {
    let fraction: Double
    let isEncore: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            Image(Art.crowd)
                .resizable()
                .frame(height: 34)
            Image(Art.crowdLit)
                .resizable()
                .frame(height: 34)
                .mask(alignment: .leading) {
                    GeometryReader { proxy in
                        Rectangle().frame(width: proxy.size.width * max(0, min(1, fraction)))
                    }
                }
            GeometryReader { proxy in
                Capsule()
                    .fill(Theme.Colors.velvetDeep.opacity(0.9))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(isEncore ? Theme.Colors.rose : Theme.Colors.saffron)
                            .frame(width: max(6, proxy.size.width * max(0, min(1, fraction))))
                    }
                    .overlay(Capsule().strokeBorder(Theme.Colors.gold, lineWidth: 1))
            }
            .frame(height: 8)
            .frame(maxHeight: .infinity, alignment: .bottom)
            Text(isEncore ? "ENCORE" : "APPLAUSE")
                .font(.engraved(12, relativeTo: .caption))
                .foregroundStyle(Theme.Colors.ivory)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(Theme.Colors.velvetDeep.opacity(0.85)))
                .frame(maxWidth: .infinity)
        }
        .frame(height: 40)
        .padding(.horizontal, 8)
        .animation(.linear(duration: 0.1), value: fraction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isEncore ? "Encore in progress" : "Applause \(Int(fraction * 100)) percent")
        .accessibilityValue("\(Int(fraction * 100))")
        .accessibilityIdentifier(AccessibilityID.Game.applause)
    }
}

struct BankButton: View {
    let isArmed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Image(isArmed ? Art.chestOpen : Art.chestClosed)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 58, height: 48)
                Text(isArmed ? "READY" : "BANK")
                    .font(.engraved(13, relativeTo: .caption))
                    .foregroundStyle(isArmed ? Theme.Colors.ink : Theme.Colors.ivory)
                    .padding(.horizontal, 8)
                    .background(Capsule().fill(isArmed ? Theme.Colors.saffron : Theme.Colors.velvetDeep.opacity(0.9)))
            }
            .frame(width: 84, height: 76)
            .background(Circle().fill(Theme.Colors.saffron.opacity(isArmed ? 0.35 : 0)).blur(radius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Bank next catch")
        .accessibilityValue(isArmed ? "Armed" : "Off")
        .accessibilityIdentifier(AccessibilityID.Game.bank)
    }
}

struct JingleButton: View {
    let fraction: Double
    let isReady: Bool
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(isActive ? Theme.Colors.teal : Theme.Colors.saffron, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 52, height: 52)
                    Image(Art.cap)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                        .saturation(isReady || isActive ? 1 : 0.25)
                }
                Text("JINGLE")
                    .font(.engraved(13, relativeTo: .caption))
                    .foregroundStyle(isReady ? Theme.Colors.ink : Theme.Colors.ivory)
                    .padding(.horizontal, 8)
                    .background(Capsule().fill(isReady ? Theme.Colors.saffron : Theme.Colors.velvetDeep.opacity(0.9)))
            }
            .frame(width: 84, height: 76)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Jingle slow motion")
        .accessibilityValue(isActive ? "Active" : isReady ? "Ready" : "Charging")
        .accessibilityIdentifier(AccessibilityID.Game.jingle)
    }
}

// MARK: - Callouts

struct CalloutView: View {
    let callout: GameViewModel.Callout

    var body: some View {
        VStack(spacing: 2) {
            Text(callout.title)
                .font(.engraved(22, relativeTo: .title2))
                .foregroundStyle(color)
            if let detail = callout.detail {
                Text(detail)
                    .font(.court(.caption, weight: .semibold))
                    .foregroundStyle(Theme.Colors.ivory)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.Colors.velvetDeep.opacity(0.82)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(color.opacity(0.7), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
    }

    private var color: Color {
        switch callout.style {
        case .gold: Theme.Colors.saffron
        case .teal: Color(red: 0.45, green: 0.9, blue: 0.88)
        case .rose: Color(red: 1, green: 0.5, blue: 0.55)
        }
    }
}

// MARK: - Playbill and pause

/// Before the show: what tonight's act is about.
struct PlaybillCard: View {
    let viewModel: GameViewModel
    let onLeave: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Tonight at Court")
                .font(.court(.caption, weight: .bold))
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(Theme.Colors.inkSoft)
            Text(viewModel.title)
                .font(.engraved(26, relativeTo: .title))
                .foregroundStyle(Theme.Colors.ink)
                .multilineTextAlignment(.center)
            Text(viewModel.subtitle)
                .font(.court(.body, weight: .medium))
                .foregroundStyle(Theme.Colors.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Image(Art.jester(viewModel.costume))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 70)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.costume.name) · \(viewModel.costume.perkTitle)")
                        .font(.court(.subheadline, weight: .bold))
                    Text(viewModel.costume.perkDetail)
                        .font(.court(.footnote))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Theme.Colors.ink)
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Colors.ink.opacity(0.06)))
            if viewModel.act != nil {
                RoseRow(roses: viewModel.previousRoses, size: 24)
            } else if case .festival = viewModel.mode, viewModel.festivalBest > 0 {
                Text("Tonight's best: \(Formatters.integer(viewModel.festivalBest))")
                    .font(.court(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.Colors.inkSoft)
            } else if viewModel.bestScore > 0 {
                Text("Best performance: \(Formatters.integer(viewModel.bestScore))")
                    .font(.court(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.Colors.inkSoft)
            }
            if let error = viewModel.startError {
                Text(error)
                    .font(.court(.footnote, weight: .semibold))
                    .foregroundStyle(Theme.Colors.rose)
            }
            Button("Begin") { viewModel.begin() }
                .buttonStyle(CourtButtonStyle(kind: .gold, size: 24, minHeight: 60))
                .accessibilityIdentifier(AccessibilityID.Game.begin)
                .disabled(viewModel.startError != nil)
            Button(action: onLeave) {
                Text("Leave the stage")
                    .font(.court(.subheadline, weight: .bold))
                    .foregroundStyle(Theme.Colors.inkSoft)
                    .frame(minWidth: 160, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.Game.quit)
        }
        .parchmentPanel(padding: 26)
        .frame(maxWidth: 440)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.velvetDeep.opacity(0.72).ignoresSafeArea())
    }
}

struct PauseCard: View {
    let viewModel: GameViewModel
    let onLeave: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Intermission")
                .font(.engraved(28, relativeTo: .title))
                .foregroundStyle(Theme.Colors.ink)
            Text("The gems hang in the air until you return.")
                .font(.court(.body, weight: .medium))
                .foregroundStyle(Theme.Colors.ink)
                .multilineTextAlignment(.center)
            Button("Resume") { viewModel.resume() }
                .buttonStyle(CourtButtonStyle(kind: .gold, size: 22))
                .accessibilityIdentifier(AccessibilityID.Game.resume)
            Button(viewModel.act == nil ? "Restart the show" : "Restart the act") { viewModel.restart() }
                .buttonStyle(CourtButtonStyle(kind: .teal, size: 18))
                .accessibilityIdentifier(AccessibilityID.Game.restart)
            Button("Leave the stage", action: onLeave)
                .buttonStyle(CourtButtonStyle(kind: .plum, size: 18))
                .accessibilityIdentifier(AccessibilityID.Game.quit)
            Text("Ducats you already banked are kept.")
                .font(.court(.footnote))
                .foregroundStyle(Theme.Colors.inkSoft)
        }
        .parchmentPanel(padding: 26)
        .frame(maxWidth: 400)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.velvetDeep.opacity(0.82).ignoresSafeArea())
    }
}
