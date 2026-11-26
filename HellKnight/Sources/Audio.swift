import AVFoundation
import QuartzCore

enum Sfx: CaseIterable {
    case swing, hit, dash, cast, enemyHurt, playerHurt, death, pickup, door, boon, explode, roar, shoot, special
}

func sfx(_ s: Sfx, _ volume: Float = 1) { Audio.shared.play(s, volume: volume) }

/// Tiny synthesizer: every sound effect is generated at launch, no audio files needed.
final class Audio {
    static let shared = Audio()

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var buffers: [Sfx: AVAudioPCMBuffer] = [:]
    private var lastPlayed: [Sfx: CFTimeInterval] = [:]
    private var index = 0
    private var started = false
    private let sampleRate: Double = 44100
    private lazy var format: AVAudioFormat? = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)

    enum Wave { case sine, square, saw, tri }

    func start() {
        guard !started, let format = format else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
        for _ in 0..<10 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        for s in Sfx.allCases {
            if let b = synth(s) { buffers[s] = b }
        }
        engine.mainMixerNode.outputVolume = 0.7
        do {
            try engine.start()
            started = true
        } catch {
            started = false
        }
    }

    func play(_ s: Sfx, volume: Float = 1) {
        guard started, let buf = buffers[s], !players.isEmpty else { return }
        let now = CACurrentMediaTime()
        if let last = lastPlayed[s], now - last < 0.035 { return }
        lastPlayed[s] = now
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        let p = players[index]
        index = (index + 1) % players.count
        p.stop()
        p.volume = volume
        p.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        p.play()
    }

    private func synth(_ s: Sfx) -> AVAudioPCMBuffer? {
        switch s {
        case .swing: return sweep(0.13, 1100, 280, .saw, noise: 0.85, vol: 0.22)
        case .hit: return sweep(0.11, 240, 70, .square, noise: 0.45, vol: 0.32)
        case .dash: return sweep(0.2, 260, 1300, .sine, noise: 0.7, vol: 0.22)
        case .cast: return sweep(0.28, 520, 1500, .tri, noise: 0.15, vol: 0.28)
        case .enemyHurt: return sweep(0.12, 420, 130, .square, noise: 0.25, vol: 0.2)
        case .playerHurt: return sweep(0.32, 320, 60, .saw, noise: 0.35, vol: 0.4)
        case .death: return sweep(0.45, 220, 40, .saw, noise: 0.55, vol: 0.3)
        case .pickup: return sweep(0.16, 620, 1500, .sine, noise: 0, vol: 0.3)
        case .door: return sweep(0.7, 90, 45, .saw, noise: 0.65, vol: 0.4)
        case .boon: return sweep(0.6, 380, 1700, .tri, noise: 0.05, vol: 0.3)
        case .explode: return sweep(0.55, 130, 28, .sine, noise: 0.85, vol: 0.55)
        case .roar: return sweep(1.1, 120, 45, .saw, noise: 0.5, vol: 0.5)
        case .shoot: return sweep(0.12, 900, 450, .square, noise: 0.1, vol: 0.12)
        case .special: return sweep(0.35, 160, 700, .saw, noise: 0.6, vol: 0.32)
        }
    }

    private func sweep(_ dur: Double, _ f0: Double, _ f1: Double, _ wave: Wave,
                       noise: Double, vol: Double, attack: Double = 0.006) -> AVAudioPCMBuffer? {
        guard let format = format else { return nil }
        let n = Int(dur * sampleRate)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n)),
              let channel = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = AVAudioFrameCount(n)
        var phase = 0.0
        var lp = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let p = t / dur
            let f = f0 * pow(f1 / f0, p)
            phase += f / sampleRate
            phase -= floor(phase)
            var v: Double
            switch wave {
            case .sine: v = sin(phase * 2 * Double.pi)
            case .square: v = phase < 0.5 ? 1 : -1
            case .saw: v = phase * 2 - 1
            case .tri: v = 1 - 4 * abs(phase - 0.5)
            }
            let r = Double.random(in: -1...1)
            lp += (r - lp) * 0.35
            v = v * (1 - noise) + lp * noise * 1.6
            let env = min(1, t / attack) * pow(1 - p, 2)
            channel[i] = Float(v * env * vol)
        }
        return buf
    }
}
