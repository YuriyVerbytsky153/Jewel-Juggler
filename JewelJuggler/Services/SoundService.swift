import AVFoundation
import Foundation

/// Generated sound effects (see `Artwork/generate_sounds.swift`).
enum SoundEffect: String, CaseIterable {
    case catch0 = "sfx_catch_0"
    case catch1 = "sfx_catch_1"
    case catch2 = "sfx_catch_2"
    case sweet = "sfx_sweet"
    case bank = "sfx_bank"
    case fuse = "sfx_fuse"
    case shatter = "sfx_shatter"
    case drop = "sfx_drop"
    case tomatoHit = "sfx_tomato_hit"
    case tomatoSplat = "sfx_tomato_splat"
    case encore = "sfx_encore"
    case decree = "sfx_decree"
    case decreeStart = "sfx_decree_start"
    case jingleReady = "sfx_jingle_ready"
    case jingle = "sfx_jingle"
    case grace = "sfx_grace"
    case count = "sfx_count"
    case go = "sfx_go"
    case tap = "sfx_tap"
    case flip = "sfx_flip"
    case buy = "sfx_buy"
    case rose = "sfx_rose"
    case finish = "sfx_finish"
    case curtain = "sfx_curtain"

    /// How many copies may overlap (rapid catches need several).
    var voices: Int {
        switch self {
        case .catch0, .catch1, .catch2, .bank, .sweet: 4
        case .tap, .tomatoSplat: 3
        default: 2
        }
    }
}

enum MusicTrack: String {
    case menu = "music_menu"
    case run = "music_run"
}

/// Plays effects and the looping music while respecting the Sound and Music settings.
/// Uses the ambient session so the game mixes with other audio and honours the silent switch.
@MainActor
final class SoundService {
    private var pools: [SoundEffect: [AVAudioPlayer]] = [:]
    private var nextVoice: [SoundEffect: Int] = [:]
    private var music: AVAudioPlayer?
    private var currentTrack: MusicTrack?
    private let soundEnabled: () -> Bool
    private let musicEnabled: () -> Bool
    private var isPrepared = false
    /// When set, every sound and music change is appended here with a wall-clock timestamp
    /// (showcase video: the recording is muxed with the same sounds afterwards).
    var eventLog: URL?

    /// A service that never plays anything (tests, previews, UI tests).
    static let silent = SoundService(soundEnabled: { false }, musicEnabled: { false })

    init(soundEnabled: @escaping () -> Bool, musicEnabled: @escaping () -> Bool) {
        self.soundEnabled = soundEnabled
        self.musicEnabled = musicEnabled
    }

    private func prepareIfNeeded() {
        guard !isPrepared else { return }
        isPrepared = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for effect in SoundEffect.allCases {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") else { continue }
            pools[effect] = (0..<effect.voices).compactMap { _ in
                let player = try? AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
                return player
            }
        }
    }

    func play(_ effect: SoundEffect, volume: Float = 1) {
        guard soundEnabled() else { return }
        prepareIfNeeded()
        guard let pool = pools[effect], !pool.isEmpty else { return }
        let index = (nextVoice[effect] ?? 0) % pool.count
        nextVoice[effect] = index + 1
        let player = pool[index]
        log(effect.rawValue, volume)
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    /// Catches climb in pitch with the number of gems in the air.
    func playCatch(airborne: Int) {
        play(airborne >= 5 ? .catch2 : airborne >= 3 ? .catch1 : .catch0, volume: 0.8)
    }

    func playMusic(_ track: MusicTrack) {
        guard musicEnabled() else { stopMusic(); return }
        prepareIfNeeded()
        if currentTrack == track, music?.isPlaying == true { return }
        music?.stop()
        guard let url = Bundle.main.url(forResource: track.rawValue, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        log("music:" + track.rawValue, 1)
        player.numberOfLoops = -1
        player.volume = 0
        player.play()
        player.setVolume(track == .run ? 0.42 : 0.35, fadeDuration: 0.8)
        music = player
        currentTrack = track
    }

    func stopMusic() {
        if music != nil { log("music:stop", 0) }
        music?.stop()
        music = nil
        currentTrack = nil
    }

    func pauseMusic() {
        if music != nil { log("music:pause", 0) }
        music?.pause()
    }

    func resumeMusic() {
        guard musicEnabled() else { return }
        if let currentTrack { log("music:resume:" + currentTrack.rawValue, 1) }
        music?.play()
    }

    private func log(_ name: String, _ volume: Float) {
        guard let eventLog else { return }
        let line = String(format: "%.3f\t%@\t%.2f\n", Date().timeIntervalSince1970, name, volume)
        if let handle = try? FileHandle(forWritingTo: eventLog) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? Data(line.utf8).write(to: eventLog)
        }
    }

    /// Re-applies the Music switch after Settings changes.
    func refreshMusic(default track: MusicTrack) {
        if musicEnabled() { playMusic(currentTrack ?? track) } else { stopMusic() }
    }
}
