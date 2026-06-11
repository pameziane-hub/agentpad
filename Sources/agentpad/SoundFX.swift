import AVFoundation
import AppKit
import AgentpadCore
import os.log

/// Synthesized sound effects in four flavors per event — no bundled audio
/// assets, so the repo stays license-clean. Users can replace them entirely
/// by dropping `shot.wav` / `reload.wav` into `~/.config/agentpad/`.
final class SoundFX {
    private let log = Logger(subsystem: "com.paulameziane.agentpad", category: "sound")
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var shotBuffers: [String: AVAudioPCMBuffer] = [:]
    private var reloadBuffers: [String: AVAudioPCMBuffer] = [:]
    private var customShot: NSSound?
    private var customReload: NSSound?
    private var systemSounds: [String: NSSound] = [:]
    private var started = false

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        shotBuffers = [
            "classic": Self.renderClassicShot(format: format),
            "laser": Self.renderLaserShot(format: format),
            "8bit": Self.render8BitShot(format: format),
            "silenced": Self.renderSilencedShot(format: format),
        ].compactMapValues { $0 }
        reloadBuffers = [
            "clack": Self.renderClack(format: format),
            "pop": Self.renderPop(format: format),
            "thock": Self.renderThock(format: format),
            "tick": Self.renderTick(format: format),
        ].compactMapValues { $0 }
        customShot = Self.customSound(named: "shot")
        customReload = Self.customSound(named: "reload")
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    /// True when the user dropped a shot.wav / reload.wav into the config dir.
    var hasCustomShot: Bool { customShot != nil }
    var hasCustomReload: Bool { customReload != nil }

    func playShot(variant: String, volume: Float) {
        log.debug("playShot variant=\(variant, privacy: .public)")
        if playSystemSound(variant, volume: volume) { return }
        if variant == "custom", let customShot {
            customShot.volume = volume
            customShot.stop()
            customShot.play()
            return
        }
        play(buffer: shotBuffers[variant] ?? shotBuffers["classic"], volume: volume)
    }

    func playReload(variant: String, volume: Float) {
        log.debug("playReload variant=\(variant, privacy: .public)")
        if playSystemSound(variant, volume: volume) { return }
        if variant == "custom", let customReload {
            customReload.volume = volume
            customReload.stop()
            customReload.play()
            return
        }
        play(buffer: reloadBuffers[variant] ?? reloadBuffers["clack"], volume: volume)
    }

    /// macOS alert sounds, played by name — nothing bundled, mastered audio.
    private func playSystemSound(_ variant: String, volume: Float) -> Bool {
        guard FxConfig.systemVariants.contains(variant) else { return false }
        let sound = systemSounds[variant] ?? NSSound(named: variant)
        guard let sound else {
            log.error("system sound \(variant, privacy: .public) unavailable")
            return true
        }
        systemSounds[variant] = sound
        sound.volume = volume
        sound.stop()
        sound.play()
        return true
    }

    private func play(buffer: AVAudioPCMBuffer?, volume: Float) {
        guard let buffer else {
            log.error("no buffer for requested variant")
            return
        }
        guard ensureEngineRunning() else { return }
        engine.mainMixerNode.outputVolume = volume
        player.scheduleBuffer(buffer, at: nil)
        player.play()
    }

    private func ensureEngineRunning() -> Bool {
        if started, engine.isRunning { return true }
        do {
            try engine.start()
            started = true
            return true
        } catch {
            log.error("audio engine start failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private static func customSound(named name: String) -> NSSound? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/agentpad/\(name).wav")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return NSSound(contentsOf: url, byReference: true)
    }

    // MARK: - Shot variants

    /// Revolver: white-noise burst over a low sine body, soft-clipped.
    private static func renderClassicShot(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        render(duration: 0.30, format: format) { t in
            let noise = Float.random(in: -1...1) * exp(-t * 26)
            let body = sinf(2 * .pi * 95 * t) * exp(-t * 14) * 0.8
            return tanhf((noise + body) * 2.4) * 0.9
        }
    }

    /// Laser: pew — linear downward chirp with a sparkle of noise.
    private static func renderLaserShot(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let duration: Float = 0.22
        let f0: Float = 1700, f1: Float = 160
        return render(duration: Double(duration), format: format) { t in
            let phase = 2 * .pi * (f0 * t + (f1 - f0) * t * t / (2 * duration))
            let chirp = sinf(phase) * exp(-t * 16)
            let sparkle = Float.random(in: -1...1) * exp(-t * 60) * 0.15
            return (chirp + sparkle) * 0.7
        }
    }

    /// 8-bit blaster: square wave stepping down an arcade arpeggio.
    private static func render8BitShot(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let steps: [Float] = [880, 587, 392, 220, 110]
        let stepLength: Float = 0.032
        return render(duration: Double(stepLength) * Double(steps.count), format: format) { t in
            let index = min(Int(t / stepLength), steps.count - 1)
            let square: Float = sinf(2 * .pi * steps[index] * t) >= 0 ? 1 : -1
            return square * 0.28 * exp(-t * 6)
        }
    }

    /// Silenced: pfft — a muffled noise puff with a low thud.
    private static func renderSilencedShot(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        render(duration: 0.18, format: format) { t in
            let puff = Float.random(in: -1...1) * exp(-t * 48) * 0.5
            let thud = sinf(2 * .pi * 62 * t) * exp(-t * 30) * 0.6
            return tanhf(puff + thud) * 0.6
        }
    }

    // MARK: - Reload variants

    /// Clack: two short mechanical clicks 90 ms apart.
    private static func renderClack(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        render(duration: 0.22, format: format) { t in
            (clickEnvelope(t, onset: 0.0) + clickEnvelope(t, onset: 0.09)) * 0.8
        }
    }

    /// Pop: a bubble pop — fast downward blip with a tiny attack click.
    private static func renderPop(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let duration: Float = 0.07
        let f0: Float = 520, f1: Float = 90
        return render(duration: Double(duration), format: format) { t in
            let phase = 2 * .pi * (f0 * t + (f1 - f0) * t * t / (2 * duration))
            let blip = sinf(phase) * exp(-t * 50)
            let attack = Float.random(in: -1...1) * exp(-t * 700) * 0.4
            return (blip + attack) * 0.8
        }
    }

    /// Thock: deep mechanical-keyboard bottom-out.
    private static func renderThock(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        render(duration: 0.09, format: format) { t in
            let body = sinf(2 * .pi * 110 * t) * exp(-t * 70)
            let tap = Float.random(in: -1...1) * exp(-t * 300) * 0.3
            return tanhf((body + tap) * 1.6) * 0.8
        }
    }

    /// Tick: a single bright, tiny click.
    private static func renderTick(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        render(duration: 0.03, format: format) { t in
            let ping = sinf(2 * .pi * 3200 * t) * exp(-t * 250) * 0.5
            let snap = Float.random(in: -1...1) * exp(-t * 500) * 0.5
            return (ping + snap) * 0.7
        }
    }

    private static func clickEnvelope(_ t: Float, onset: Float) -> Float {
        let local = t - onset
        guard local >= 0, local < 0.05 else { return 0 }
        let noise = Float.random(in: -1...1) * exp(-local * 160)
        let tone = sinf(2 * .pi * 1900 * local) * exp(-local * 120) * 0.5
        return noise * 0.7 + tone
    }

    private static func render(duration: Double, format: AVAudioFormat,
                               sample: (Float) -> Float) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for frame in 0..<Int(frameCount) {
            channel[frame] = sample(Float(frame) / Float(format.sampleRate))
        }
        return buffer
    }
}
