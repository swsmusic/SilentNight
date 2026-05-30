import SwiftUI
import Combine
import AVFoundation

/// Controls brown noise playback with adjustable volume and noise type
final class AudioEngine: ObservableObject {
    private var audioPlayer: AVAudioPlayerNode?
    private var audioEngine: AVAudioEngine?
    private var distortion: AVAudioUnitDistortion?

    @Published var isPlaying = false
    @Published var volume: Double = 0.5 {
        didSet { adjustVolume() }
    }
    @Published var noiseType: NoiseType = .brown
    @Published var isAutoMode = false

    enum NoiseType: String, CaseIterable {
        case brown = "Brown"
        case pink = "Pink"
        case white = "White"
        case grey = "Grey"

        var displayName: String { rawValue }

        var color: (r: Double, g: Double, b: Double) {
            switch self {
            case .brown: return (0.6, 0.4, 0.2)
            case .pink: return (0.9, 0.5, 0.6)
            case .white: return (0.9, 0.9, 0.9)
            case .grey: return (0.7, 0.7, 0.7)
            }
        }
    }

    init() {
        setupAudioSession()
        pregenerateNoise()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .playAndRecord so MicMonitor + playback can coexist for Anti-Snore.
            // .defaultToSpeaker so audio routes to speaker (not earpiece) when mic is also active.
            try session.setCategory(.playAndRecord,
                                    mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    private func pregenerateNoise() {
        // Generate noise buffer when user selects a type
    }

    // MARK: - Playback Control

    func play() {
        if audioEngine == nil {
            setupNoisePipeline()
        }
        guard let engine = audioEngine, let player = audioPlayer else {
            print("AudioEngine: pipeline not ready")
            isPlaying = false
            return
        }
        do {
            if !engine.isRunning {
                try engine.start()
            }
            player.play()
            isPlaying = true
        } catch {
            print("AudioEngine failed to start: \(error)")
            isPlaying = false
        }
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }

    func stop() {
        audioPlayer?.stop()
        isPlaying = false
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    /// Increase volume to cover detected snoring. `multiplier` is the
    /// SnoreLevel-derived intensity (0.0 none .. 0.2 high). Called when the
    /// detected snore level changes in MicMonitor while Anti-Snore is on.
    func boostForSnoring(multiplier: Float) {
        guard isAutoMode, multiplier > 0 else { return }
        volume = min(1.0, volume + Double(multiplier))
    }

    // MARK: - Noise Pipeline

    private func setupNoisePipeline() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()

        // Generate buffer first so we can use its format for connection
        let buffer = generateNoiseBuffer(for: noiseType)

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: buffer.format)

        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)

        self.audioEngine = engine
        self.audioPlayer = player
        adjustVolume()
    }

    private func scheduleBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let player = audioPlayer else { return }
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
    }

    private func adjustVolume() {
        audioPlayer?.volume = Float(volume)
    }

    // MARK: - Noise Generation

    func setNoiseType(_ type: NoiseType) {
        let wasPlaying = isPlaying
        if wasPlaying { stop() }
        noiseType = type
        if wasPlaying { play() }
    }

    private func generateNoiseBuffer(for type: NoiseType) -> AVAudioPCMBuffer {
        let sampleRate: Double = 44100
        let duration: Double = 4.0  // 4 second loop
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let samples = buffer.floatChannelData![0]

        switch type {
        case .brown:
            generateBrownNoise(samples: samples, frameCount: Int(frameCount))
        case .white:
            generateWhiteNoise(samples: samples, frameCount: Int(frameCount))
        case .pink:
            generatePinkNoise(samples: samples, frameCount: Int(frameCount))
        case .grey:
            generateGreyNoise(samples: samples, frameCount: Int(frameCount))
        }

        return buffer
    }

    private func generateBrownNoise(samples: UnsafeMutablePointer<Float>, frameCount: Int) {
        var lastOut: Float = 0
        for i in 0..<frameCount {
            let white = Float.random(in: -1...1)
            lastOut = (lastOut + (0.02 * white)) / 1.02
            samples[i] = lastOut * 3.5
        }
    }

    private func generateWhiteNoise(samples: UnsafeMutablePointer<Float>, frameCount: Int) {
        for i in 0..<frameCount {
            samples[i] = Float.random(in: -1...1)
        }
    }

    private func generatePinkNoise(samples: UnsafeMutablePointer<Float>, frameCount: Int) {
        // Simplified pink noise using Voss-McCartney algorithm
        var b0: Float = 0, b1: Float = 0, b2: Float = 0
        var b3: Float = 0, b4: Float = 0, b5: Float = 0, b6: Float = 0

        for i in 0..<frameCount {
            let white = Float.random(in: -1...1)
            b0 = 0.99886 * b0 + white * 0.0555179
            b1 = 0.99332 * b1 + white * 0.0750759
            b2 = 0.96900 * b2 + white * 0.1538520
            b3 = 0.86650 * b3 + white * 0.3104856
            b4 = 0.55000 * b4 + white * 0.5329522
            b5 = -0.7616 * b5 - white * 0.0168980
            let pink = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362
            b6 = white * 0.115926
            samples[i] = pink * 0.11
        }
    }

    private func generateGreyNoise(samples: UnsafeMutablePointer<Float>, frameCount: Int) {
        // Grey noise: white noise with psychoacoustic equal-loudness curve approximation
        generateWhiteNoise(samples: samples, frameCount: frameCount)
        // Apply simple A-weighting approximation in time domain
        let alpha: Float = 0.99
        for i in 1..<frameCount {
            samples[i] = alpha * samples[i-1] + (1 - alpha) * samples[i]
        }
    }
}
