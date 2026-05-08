import AVFoundation

final class AudioManager {
    static let shared = AudioManager()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let monoFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private var isStarted = false

    private init() {
        engine.attach(player)
        // Connect with an explicit mono format so scheduled mono buffers don't
        // mismatch against a stereo output format inferred from hardware.
        engine.connect(player, to: engine.mainMixerNode, format: monoFormat)
    }

    // Three ascending beeps matching the HTML original (880 → 1100 → 1320 Hz)
    func timerDone() {
        scheduleBeep(frequency: 880,  duration: 0.10, delay: 0.00)
        scheduleBeep(frequency: 1100, duration: 0.12, delay: 0.15)
        scheduleBeep(frequency: 1320, duration: 0.18, delay: 0.30)
    }

    // MARK: - Private

    private func scheduleBeep(frequency: Float, duration: Float, delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.playTone(frequency: frequency, duration: duration)
        }
    }

    private func startEngine() {
        guard !isStarted else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback, mode: .default, options: .mixWithOthers
            )
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            isStarted = true
        } catch {
            // Beeps are non-critical; silent failure is acceptable
        }
    }

    private func playTone(frequency: Float, duration: Float) {
        startEngine()
        guard isStarted else { return }

        let sampleRate: Double = 44100
        let frameCount = AVAudioFrameCount(sampleRate * Double(duration))

        guard
            let buffer  = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: frameCount),
            let samples = buffer.floatChannelData?[0]
        else { return }

        buffer.frameLength = frameCount

        for i in 0..<Int(frameCount) {
            let t       = Float(i) / Float(sampleRate)
            let fadeIn  = min(t / 0.010, 1.0)                         // 10 ms attack
            let fadeOut = max(0, min((duration - t) / 0.040, 1.0))    // 40 ms release
            samples[i]  = sinf(2 * .pi * frequency * t) * 0.30 * min(fadeIn, fadeOut)
        }

        if !player.isPlaying { player.play() }
        player.scheduleBuffer(buffer)
    }
}
