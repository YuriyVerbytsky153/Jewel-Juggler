// Jewel Juggler sound generator.
// Synthesises every sound effect and the two court music loops as 16-bit mono WAV files.
// Deterministic: noise uses a fixed seed. Usage: swift generate_sounds.swift "<output dir>"

import Foundation

let rate = 44_100.0
let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./Sounds")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

var noiseState: UInt64 = 0x1234_5678
func noise() -> Double {
    noiseState ^= noiseState << 13; noiseState ^= noiseState >> 7; noiseState ^= noiseState << 17
    return Double(noiseState % 20_000) / 10_000 - 1
}

struct Buffer {
    var s: [Double]
    init(_ seconds: Double) { s = Array(repeating: 0, count: Int(seconds * rate)) }
    var count: Int { s.count }
    mutating func add(_ other: Buffer, at t: Double, gain: Double = 1) {
        let o = Int(t * rate)
        for i in 0..<other.count where o + i < count && o + i >= 0 { s[o + i] += other.s[i] * gain }
    }
}

enum Wave { case sine, square, saw, triangle, noise }
func osc(_ w: Wave, _ phase: Double) -> Double {
    let p = phase - floor(phase)
    switch w {
    case .sine: return sin(p * 2 * .pi)
    case .square: return p < 0.5 ? 1 : -1
    case .saw: return 2 * p - 1
    case .triangle: return 4 * abs(p - 0.5) - 1
    case .noise: return noise()
    }
}

/// A tone whose frequency glides from f0 to f1, shaped by an attack/decay envelope.
func tone(_ w: Wave, _ f0: Double, _ f1: Double, _ dur: Double, attack: Double = 0.005, decay: Double? = nil, vibrato: Double = 0, vibRate: Double = 6, curve: Double = 1) -> Buffer {
    var b = Buffer(dur)
    var phase = 0.0
    for i in 0..<b.count {
        let t = Double(i) / rate
        let k = pow(t / dur, curve)
        let f = f0 + (f1 - f0) * k + vibrato * sin(2 * .pi * vibRate * t)
        phase += f / rate
        let env: Double
        if t < attack { env = t / attack } else {
            let d = decay ?? (dur - attack)
            env = max(0, 1 - (t - attack) / d)
        }
        b.s[i] = osc(w, phase) * env * env
    }
    return b
}
func noiseBurst(_ dur: Double, attack: Double = 0.003, lowpass: Double = 1, highpass: Double = 0, curve: Double = 2) -> Buffer {
    var b = Buffer(dur)
    var lp = 0.0, hpPrev = 0.0, hpOut = 0.0
    for i in 0..<b.count {
        let t = Double(i) / rate
        let env = t < attack ? t / attack : pow(max(0, 1 - (t - attack) / (dur - attack)), curve)
        let n = noise()
        lp += (n - lp) * lowpass
        hpOut = highpass > 0 ? highpass * (hpOut + lp - hpPrev) : lp
        hpPrev = lp
        b.s[i] = hpOut * env
    }
    return b
}
func lowpass(_ b: inout Buffer, _ a: Double) { var y = 0.0; for i in 0..<b.count { y += (b.s[i] - y) * a; b.s[i] = y } }

func write(_ name: String, _ b: Buffer, gain: Double = 0.8) {
    let peak = max(0.0001, b.s.map { abs($0) }.max() ?? 1)
    let scale = gain / peak
    var data = Data()
    func u32(_ v: UInt32) { var x = v.littleEndian; data.append(Data(bytes: &x, count: 4)) }
    func u16(_ v: UInt16) { var x = v.littleEndian; data.append(Data(bytes: &x, count: 2)) }
    let bytes = UInt32(b.count * 2)
    data.append("RIFF".data(using: .ascii)!); u32(36 + bytes); data.append("WAVE".data(using: .ascii)!)
    data.append("fmt ".data(using: .ascii)!); u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
    data.append("data".data(using: .ascii)!); u32(bytes)
    for v in b.s { var x = Int16(max(-1, min(1, v * scale)) * 32_000).littleEndian; data.append(Data(bytes: &x, count: 2)) }
    try! data.write(to: outDir.appendingPathComponent("\(name).wav"))
}

// MARK: - Effects

/// A plucked string (lute-like): bright attack, fast decay, a touch of octave.
func pluck(_ f: Double, _ dur: Double) -> Buffer {
    var b = tone(.triangle, f, f, dur, attack: 0.002, decay: dur * 0.6)
    b.add(tone(.sine, f * 2, f * 2, dur * 0.5, attack: 0.002), at: 0, gain: 0.35)
    b.add(noiseBurst(0.01, lowpass: 0.6), at: 0, gain: 0.15)
    return b
}

/// A small bell: inharmonic partials.
func bellTone(_ f: Double, _ dur: Double) -> Buffer {
    var b = Buffer(dur)
    for (ratio, g) in [(1.0, 0.6), (2.76, 0.22), (5.4, 0.1), (8.93, 0.05)] { b.add(tone(.sine, f * ratio, f * ratio, dur, attack: 0.001), at: 0, gain: g) }
    return b
}

for (i, f) in [880.0, 988, 1175].enumerated() { // Catch: soft glassy tick that climbs with gems aloft.
    var b = tone(.sine, f, f * 1.2, 0.08, attack: 0.002)
    b.add(tone(.triangle, f * 2.5, f * 2.6, 0.05, attack: 0.001), at: 0, gain: 0.25)
    b.add(noiseBurst(0.015, lowpass: 0.7, highpass: 0.8), at: 0, gain: 0.2)
    write("sfx_catch_\(i)", b, gain: 0.45)
}
do { write("sfx_sweet", bellTone(2349, 0.35), gain: 0.35) }
do { // Bank: coins clink into the chest, lid thump.
    var b = Buffer(0.5)
    b.add(tone(.sine, 140, 70, 0.12, attack: 0.002), at: 0, gain: 0.7)
    for (t, f) in [(0.03, 2637.0), (0.09, 3136), (0.16, 2794)] { b.add(bellTone(f, 0.22), at: t, gain: 0.45) }
    write("sfx_bank", b, gain: 0.6)
}
do { // Fuse: rising shimmering chord.
    var b = Buffer(0.9)
    for (i, f) in [659.25, 830.6, 987.8, 1318.5].enumerated() { b.add(bellTone(f, 0.6), at: Double(i) * 0.06, gain: 0.4) }
    b.add(noiseBurst(0.5, attack: 0.1, lowpass: 0.3, highpass: 0.7, curve: 1.5), at: 0, gain: 0.15)
    write("sfx_fuse", b, gain: 0.6)
}
do { // Shatter: glass burst.
    var b = noiseBurst(0.45, lowpass: 0.9, highpass: 0.6, curve: 3)
    for f in [3520.0, 4186, 2960, 5274] { b.add(tone(.sine, f, f * 0.97, 0.3, attack: 0.001), at: abs(noise()) * 0.05, gain: 0.15) }
    b.add(tone(.sine, 200, 80, 0.15, attack: 0.002), at: 0, gain: 0.5)
    write("sfx_shatter", b, gain: 0.7)
}
do { // Drop: thud on the boards and a sour bell.
    var b = Buffer(0.7)
    b.add(tone(.sine, 110, 45, 0.25, attack: 0.002), at: 0, gain: 1)
    b.add(noiseBurst(0.12, lowpass: 0.25), at: 0, gain: 0.4)
    b.add(bellTone(466, 0.5), at: 0.08, gain: 0.35)
    b.add(bellTone(440, 0.5), at: 0.12, gain: 0.3)
    write("sfx_drop", b, gain: 0.75)
}
do { // Tomato in the face.
    var b = noiseBurst(0.3, lowpass: 0.12, curve: 2)
    b.add(tone(.sine, 260, 70, 0.22, attack: 0.002), at: 0, gain: 0.8)
    b.add(tone(.square, 300, 200, 0.18, attack: 0.01), at: 0.08, gain: 0.08)
    write("sfx_tomato_hit", b, gain: 0.75)
}
do { var b = noiseBurst(0.18, lowpass: 0.1, curve: 2); b.add(tone(.sine, 180, 60, 0.12, attack: 0.002), at: 0, gain: 0.5); write("sfx_tomato_splat", b, gain: 0.5) }
do { // Encore: crowd applause swell and a fanfare.
    var b = Buffer(1.6)
    var clap = Buffer(1.5)
    for k in 0..<60 { clap.add(noiseBurst(0.03, lowpass: 0.7, highpass: 0.7, curve: 3), at: Double(k) * 0.024 + abs(noise()) * 0.01, gain: 0.4 * sin(Double(k) / 60 * .pi)) }
    b.add(clap, at: 0, gain: 0.8)
    for (t, f) in [(0.0, 523.25), (0.12, 659.25), (0.24, 783.99), (0.36, 1046.5)] {
        var n = tone(.saw, f, f, t == 0.36 ? 0.6 : 0.14, attack: 0.01); lowpass(&n, 0.2); b.add(n, at: t, gain: 0.35)
    }
    write("sfx_encore", b, gain: 0.7)
}
do { // Decree: herald trumpet call.
    var b = Buffer(0.9)
    for (t, f, d) in [(0.0, 392.0, 0.12), (0.14, 392.0, 0.12), (0.28, 523.25, 0.5)] {
        var n = tone(.saw, f, f, d, attack: 0.015, vibrato: f * 0.006, vibRate: 6); lowpass(&n, 0.18); b.add(n, at: t, gain: 0.6)
    }
    write("sfx_decree", b, gain: 0.6)
}
do { // Decree in force: drum roll and hit.
    var b = Buffer(0.8)
    for k in 0..<16 { b.add(noiseBurst(0.04, lowpass: 0.35, curve: 2), at: Double(k) * 0.03, gain: 0.25 + Double(k) * 0.02) }
    b.add(tone(.sine, 90, 40, 0.3, attack: 0.002), at: 0.5, gain: 1)
    write("sfx_decree_start", b, gain: 0.7)
}
do { var b = Buffer(0.6); for (i, f) in [1568.0, 1976, 2349].enumerated() { b.add(bellTone(f, 0.4), at: Double(i) * 0.07, gain: 0.4) }; write("sfx_jingle_ready", b, gain: 0.45) }
do { // Jingle: shaken cap bells with a slowing whoosh.
    var b = Buffer(1.0)
    for k in 0..<14 { b.add(bellTone([1760.0, 2093, 2349][k % 3], 0.25), at: Double(k) * 0.045, gain: 0.25) }
    b.add(tone(.sine, 900, 220, 0.9, attack: 0.05, curve: 0.6), at: 0, gain: 0.2)
    write("sfx_jingle", b, gain: 0.55)
}
do { write("sfx_grace", bellTone(1318.5, 0.7), gain: 0.45) }
do { write("sfx_count", pluck(392, 0.2), gain: 0.4) }
do { var b = pluck(784, 0.4); b.add(pluck(523.25, 0.4), at: 0, gain: 0.7); write("sfx_go", b, gain: 0.5) }
do { var b = tone(.sine, 1400, 1000, 0.03, attack: 0.001); b.add(noiseBurst(0.02, lowpass: 0.8), at: 0, gain: 0.3); write("sfx_tap", b, gain: 0.3) }
do { write("sfx_flip", noiseBurst(0.12, attack: 0.03, lowpass: 0.5, highpass: 0.8, curve: 1.5), gain: 0.4) }
do { var b = Buffer(0.5); for (i, f) in [1568.0, 2093, 2637].enumerated() { b.add(bellTone(f, 0.3), at: Double(i) * 0.06, gain: 0.45) }; write("sfx_buy", b, gain: 0.5) }
do { var b = Buffer(0.6); b.add(pluck(659.25, 0.3), at: 0); b.add(pluck(987.8, 0.4), at: 0.1); write("sfx_rose", b, gain: 0.5) }
do { // Curtain call fanfare.
    var b = Buffer(1.4)
    for (t, f, d) in [(0.0, 523.25, 0.14), (0.15, 659.25, 0.14), (0.3, 783.99, 0.14), (0.45, 1046.5, 0.7)] {
        var n = tone(.saw, f, f, d, attack: 0.01, vibrato: f * 0.004); lowpass(&n, 0.2); b.add(n, at: t, gain: 0.45)
        b.add(pluck(f / 2, d + 0.2), at: t, gain: 0.4)
    }
    write("sfx_finish", b, gain: 0.6)
}
do { // Curtain falls: slow descending lute.
    var b = Buffer(1.5)
    for (i, f) in [392.0, 349.2, 311.1, 293.7].enumerated() { b.add(pluck(f, i == 3 ? 0.9 : 0.4), at: Double(i) * 0.28, gain: 0.7) }
    b.add(noiseBurst(1.2, attack: 0.4, lowpass: 0.05, curve: 1.5), at: 0.2, gain: 0.3)
    write("sfx_curtain", b, gain: 0.6)
}

// MARK: - Music loops (court dances in D dorian)

func midi(_ n: Int) -> Double { 440 * pow(2, Double(n - 69) / 12) }

func renderDance(bpm: Double, bars: Int, lead: [(Double, Int, Double)], bass: [(Double, Int, Double)], tambourine: Bool) -> Buffer {
    let beat = 60 / bpm
    var b = Buffer(beat * 4 * Double(bars))
    func place(_ n: Buffer, _ t: Double, _ g: Double) {
        let o = Int(t * rate)
        for i in 0..<n.count { b.s[(o + i) % b.count] += n.s[i] * g }
    }
    for (pos, note, len) in lead {
        var n = tone(.triangle, midi(note), midi(note), len * beat * 0.95, attack: 0.01, decay: len * beat * 1.2, vibrato: midi(note) * 0.005, vibRate: 5)
        n.add(tone(.sine, midi(note) * 2, midi(note) * 2, len * beat * 0.6, attack: 0.01), at: 0, gain: 0.2)
        place(n, pos * beat, 0.3)
    }
    for (pos, note, len) in bass { place(pluck(midi(note), len * beat), pos * beat, 0.55) }
    for k in 0..<(bars * 4) {
        place(tone(.sine, 95, 50, 0.14, attack: 0.002), Double(k) * beat, k % 2 == 0 ? 0.5 : 0.18)
        if tambourine {
            place(noiseBurst(0.06, lowpass: 0.95, highpass: 0.92, curve: 2.5), (Double(k) + 0.5) * beat, 0.14)
            for j in 0..<3 { place(bellTone(4186, 0.05), (Double(k) + 0.5) * beat + Double(j) * 0.012, 0.03) }
        }
    }
    return b
}

do { // Show loop: lively galliard, 8 bars at 132 bpm.
    let prog = [50, 48, 50, 45, 50, 48, 53, 45] // Dm C Dm Am Dm C F Am
    var bass: [(Double, Int, Double)] = []
    for (bar, root) in prog.enumerated() { for k in 0..<4 { bass.append((Double(bar * 4 + k), root + [0, 7, 12, 7][k], 0.8)) } }
    let phrase: [(Double, Int, Double)] = [
        (0, 74, 0.5), (0.5, 76, 0.5), (1, 77, 1), (2, 76, 0.5), (2.5, 74, 0.5), (3, 72, 1),
        (4, 74, 0.5), (4.5, 72, 0.5), (5, 69, 1), (6, 71, 0.5), (6.5, 72, 0.5), (7, 74, 1),
        (8, 77, 0.5), (8.5, 79, 0.5), (9, 81, 1), (10, 79, 0.5), (10.5, 77, 0.5), (11, 76, 1),
        (12, 77, 0.5), (12.5, 76, 0.5), (13, 74, 0.5), (13.5, 72, 0.5), (14, 74, 2),
    ]
    let lead = phrase + phrase.map { ($0.0 + 16, $0.1, $0.2) }
    write("music_run", renderDance(bpm: 132, bars: 8, lead: lead, bass: bass, tambourine: true), gain: 0.5)
}
do { // Menu loop: slow pavane, 8 bars at 84 bpm.
    let prog = [50, 50, 48, 48, 46, 46, 45, 45]
    var bass: [(Double, Int, Double)] = []
    for (bar, root) in prog.enumerated() { bass.append((Double(bar * 4), root, 1.8)); bass.append((Double(bar * 4 + 2), root + 7, 1.8)) }
    let lead: [(Double, Int, Double)] = [
        (0, 74, 2), (2, 72, 1), (3, 74, 1), (4, 76, 2), (6, 74, 2),
        (8, 72, 2), (10, 70, 1), (11, 72, 1), (12, 74, 4),
        (16, 77, 2), (18, 76, 1), (19, 74, 1), (20, 72, 2), (22, 70, 2),
        (24, 69, 2), (26, 71, 1), (27, 73, 1), (28, 74, 4),
    ]
    write("music_menu", renderDance(bpm: 84, bars: 8, lead: lead, bass: bass, tambourine: false), gain: 0.45)
}
print("Sounds written to \(outDir.path)")
