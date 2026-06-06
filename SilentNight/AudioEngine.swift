import SwiftUI
import Combine
import AVFoundation
import MediaPlayer

/// Controls noise playback with adjustable volume and noise type.
/// Designed to recover gracefully from interruptions, route changes, and
/// audio-stack resets so the user can switch sounds repeatedly without
/// silent failure.
final class AudioEngine: ObservableObject {
    private var audioPlayer: AVAudioPlayerNode?
    private var audioEngine: AVAudioEngine?
    private var currentBuffer: AVAudioPCMBuffer?
    private var fadeTimer: Timer?
    private var targetPlayerVolume: Float = 0.5
    private let fadeDuration: TimeInterval = 1.2
    private let fadeStepInterval: TimeInterval = 0.05

    @Published var isPlaying = false {
        didSet { updateNowPlayingInfo() }
    }
    @Published var volume: Double = 0.5 {
        didSet {
            targetPlayerVolume = Float(volume)
            adjustVolume()
        }
    }
    @Published var noiseType: NoiseType = .brown {
        didSet { updateNowPlayingInfo() }
    }
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
        registerSystemObservers()
        setupRemoteCommands()
        updateNowPlayingInfo()
    }

    deinit {
        fadeTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Note: no .mixWithOthers — the app must own the audio session to
            // appear as the system "Now Playing" app (lock screen / Control
            // Center / Home Screen media controls). Mixing with others demotes
            // us to an ambient source that the player UI ignores.
            try session.setCategory(.playAndRecord,
                                    mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: [])
        } catch {
            print("AudioEngine session setup failed: \(error)")
        }
    }

    // MARK: - System Observers (interruptions / route / reset)

    private func registerSystemObservers() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleInterruption(_:)),
                       name: AVAudioSession.interruptionNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleRouteChange(_:)),
                       name: AVAudioSession.routeChangeNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleMediaServicesReset(_:)),
                       name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleEngineConfigurationChange(_:)),
                       name: .AVAudioEngineConfigurationChange, object: nil)
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard
            let info = note.userInfo,
            let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeRaw)
        else { return }
        switch type {
        case .began:
            // System paused us (phone call, alarm, Siri). Reflect in UI.
            isPlaying = false
        case .ended:
            // If system says we should resume, do it.
            if let optionsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
                if options.contains(.shouldResume) { play() }
            }
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ note: Notification) {
        // Audio route changed (e.g., Bluetooth disconnect). Refresh engine if running.
        guard isPlaying, let engine = audioEngine else { return }
        if !engine.isRunning {
            do { try engine.start() } catch {
                print("Route-change engine restart failed: \(error)")
                isPlaying = false
            }
        }
    }

    @objc private func handleMediaServicesReset(_ note: Notification) {
        // The whole audio stack reset. Tear down and rebuild from scratch.
        let wasPlaying = isPlaying
        tearDownPipeline()
        setupAudioSession()
        if wasPlaying { play() }
    }

    @objc private func handleEngineConfigurationChange(_ note: Notification) {
        // Engine itself reconfigured (e.g., new hardware format). Restart it.
        guard isPlaying, let engine = audioEngine else { return }
        if !engine.isRunning {
            do { try engine.start() } catch {
                print("Engine reconfigure restart failed: \(error)")
                isPlaying = false
            }
        }
    }

    // MARK: - Playback Control

    func play() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        ensurePipelineReady()
        guard let engine = audioEngine, let player = audioPlayer else {
            print("AudioEngine: pipeline not ready")
            isPlaying = false
            return
        }
        do {
            if !engine.isRunning { try engine.start() }
            // If the player was previously stopped (not just paused), its scheduled
            // buffer is consumed. Reschedule so .play() actually plays something.
            if !player.isPlaying { rescheduleBufferIfNeeded() }
            player.volume = 0
            player.play()
            isPlaying = true
            fadePlayerVolume(to: targetPlayerVolume, duration: fadeDuration)
        } catch {
            print("AudioEngine failed to start: \(error)")
            isPlaying = false
        }
    }

    func pause() {
        guard isPlaying, let player = audioPlayer else {
            audioPlayer?.pause()
            isPlaying = false
            return
        }
        isPlaying = false
        fadePlayerVolume(to: 0, duration: fadeDuration) { [weak player] in
            player?.pause()
        }
    }

    func stop() {
        guard isPlaying, let player = audioPlayer else {
            audioPlayer?.stop()
            // Keep the engine alive but reset the player state. Next play() will
            // reschedule the buffer and resume.
            audioEngine?.pause()
            isPlaying = false
            return
        }
        isPlaying = false
        fadePlayerVolume(to: 0, duration: fadeDuration) { [weak self, weak player] in
            player?.stop()
            // Keep the engine alive but reset the player state. Next play() will
            // reschedule the buffer and resume.
            self?.audioEngine?.pause()
        }
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    /// Increase volume in response to detected snoring. `multiplier` is the
    /// SnoreLevel-derived intensity (0..0.2). Wired from
    /// `NowPlayingView.onChange(of: micMonitor.snoreLevel)`.
    func boostForSnoring(multiplier: Float) {
        guard isAutoMode, multiplier > 0 else { return }
        volume = min(1.0, volume + Double(multiplier))
    }

    // MARK: - Now Playing / Remote Controls

    /// Wire lock screen / Control Center / headphone play-pause buttons to the
    /// engine so the noise behaves like a music app the system can pause.
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.play()
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.pause()
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.togglePlayPause()
            return .success
        }

        // Endless noise has no track to skip; disable transport we can't honor.
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
        center.changePlaybackPositionCommand.isEnabled = false
    }

    /// Publish the current noise as the system Now Playing item so it appears in
    /// the lock screen / Control Center player with a working pause control.
    private func updateNowPlayingInfo() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: "\(noiseType.displayName) Noise",
            MPMediaItemPropertyArtist: "SilentNight",
            // Continuous noise — a live stream has no scrubber or duration.
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    // MARK: - Noise Pipeline

    private func ensurePipelineReady() {
        guard audioEngine == nil else { return }
        buildPipeline()
    }

    private func buildPipeline() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()

        let buffer = generateNoiseBuffer(for: noiseType)

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)

        self.audioEngine = engine
        self.audioPlayer = player
        self.currentBuffer = buffer
        adjustVolume()
    }

    private func rescheduleBufferIfNeeded() {
        guard let player = audioPlayer else { return }
        let buffer = currentBuffer ?? generateNoiseBuffer(for: noiseType)
        currentBuffer = buffer
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
    }

    private func tearDownPipeline() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        audioPlayer?.stop()
        audioEngine?.stop()
        audioEngine = nil
        audioPlayer = nil
        currentBuffer = nil
    }

    private func adjustVolume() {
        guard fadeTimer == nil else { return }
        audioPlayer?.volume = targetPlayerVolume
    }

    private func fadePlayerVolume(to destination: Float,
                                  duration: TimeInterval,
                                  completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()

        guard let player = audioPlayer else {
            completion?()
            return
        }

        let start = player.volume
        let steps = max(1, Int(duration / fadeStepInterval))
        var currentStep = 0

        fadeTimer = Timer.scheduledTimer(withTimeInterval: fadeStepInterval, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            currentStep += 1
            let progress = min(1, Float(currentStep) / Float(steps))
            player.volume = start + ((destination - start) * progress)

            if currentStep >= steps {
                timer.invalidate()
                self.fadeTimer = nil
                player.volume = destination
                completion?()
            }
        }

        if let fadeTimer {
            RunLoop.main.add(fadeTimer, forMode: .common)
        }
    }

    // MARK: - Noise Generation

    func setNoiseType(_ type: NoiseType) {
        guard type != noiseType else { return }
        let wasPlaying = isPlaying
        // Hard tear-down so the next play() builds a fresh buffer of the NEW
        // type. Without this, the looping buffer of the OLD type keeps playing
        // and the switch silently does nothing.
        tearDownPipeline()
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
        // Voss-McCartney algorithm
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
        // Grey noise: white noise with simple equal-loudness smoothing.
        generateWhiteNoise(samples: samples, frameCount: frameCount)
        let alpha: Float = 0.99
        for i in 1..<frameCount {
            samples[i] = alpha * samples[i-1] + (1 - alpha) * samples[i]
        }
    }
}
