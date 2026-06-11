import AVFoundation
import AppKit

/// Synthesized western-mode sounds — no bundled audio assets, so the repo
/// stays license-clean. Users can replace them by dropping `shot.wav` /
/// `reload.wav` into `~/.config/agentpad/`.
final class SoundFX {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var shotBuffer: AVAudioPCMBuffer?
    private var reloadBuffer: AVAudioPCMBuffer?
    private var customShot: NSSound?
    private var customReload: NSSound?
    private var started = false

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        shotBuffer = Self.renderShot(format: format)
        reloadBuffer = Self.renderReload(format: format)
        customShot = Self.customSound(named: "shot")
        customReload = Self.customSound(named: "reload")
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func playShot() { play(custom: customShot, buffer: shotBuffer) }
    func playReload() { play(custom: customReload, buffer: reloadBuffer) }

    private func play(custom: NSSound?, buffer: AVAudioPCMBuffer?) {
        if let custom {
            custom.stop()
            custom.play()
            return
        }
        guard let buffer, ensureEngineRunning() else { return }
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
            return false
        }
    }

    private static func customSound(named name: String) -> NSSound? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/agentpad/\(name).wav")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return NSSound(contentsOf: url, byReference: true)
    }

    // MARK: - Synthesis

    /// Gunshot: white-noise burst with a fast exponential decay over a low
    /// sine "body", soft-clipped for punch.
    private static func renderShot(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        render(duration: 0.30, format: format) { t in
            let noise = Float.random(in: -1...1) * exp(-t * 26)
            let body = sinf(2 * .pi * 95 * t) * exp(-t * 14) * 0.8
            return tanhf((noise + body) * 2.4) * 0.9
        }
    }

    /// Reload: two short filtered clicks ("clack-clack") 90 ms apart.
    private static func renderReload(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        render(duration: 0.22, format: format) { t in
            let first = clickEnvelope(t, onset: 0.0)
            let second = clickEnvelope(t, onset: 0.09)
            return (first + second) * 0.8
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
