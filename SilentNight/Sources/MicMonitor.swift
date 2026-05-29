import AVFoundation
import Combine

/// Monitors microphone input to detect snoring patterns and adjust noise accordingly
final class MicMonitor: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    @Published var isMonitoring = false
    @Published var currentLevel: Float = 0.0
    @Published var snoreLevel: SnoreLevel = .none

    /// Sensitivity threshold for snoring detection (0.0 - 1.0)
    @Published var sensitivity: Double = 0.5

    enum SnoreLevel: Int, CaseIterable {
        case none = 0
        case low = 1
        case medium = 2
        case high = 3

        var label: String {
            switch self {
            case .none: return "None"
            case .low: return "Light"
            case .medium: return "Moderate"
            case .high: return "Heavy"
            }
        }

        var color: (r: Double, g: Double, b: Double) {
            switch self {
            case .none: return (0.3, 0.8, 0.3)
            case .low: return (0.5, 0.7, 0.2)
            case .medium: return (0.9, 0.6, 0.1)
            case .high: return (0.9, 0.2, 0.2)
            }
        }

        var volumeBoostMultiplier: Float {
            switch self {
            case .none: return 0.0
            case .low: return 0.05
            case .medium: return 0.12
            case .high: return 0.2
            }
        }
    }

    init() {
        // Don't request mic permission until user enables monitoring
    }

    // MARK: - Control

    func startMonitoring() {
        requestMicrophonePermission { [weak self] granted in
            guard granted else {
                print("Microphone permission denied")
                return
            }
            DispatchQueue.main.async {
                self?.setupMicPipeline()
            }
        }
    }

    func stopMonitoring() {
        audioEngine?.stop()
        audioEngine = nil
        isMonitoring = false
        currentLevel = 0
        snoreLevel = .none
    }

    func toggleMonitoring() {
        if isMonitoring { stopMonitoring() } else { startMonitoring() }
    }

    // MARK: - Permission

    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            completion(granted)
        }
    }

    // MARK: - Microphone Pipeline

    private func setupMicPipeline() {
        let engine = AVAudioEngine()
        let input = engine.inputNode

        let format = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        audioEngine = engine
        self.inputNode = input

        do {
            try engine.start()
            isMonitoring = true
        } catch {
            print("Mic engine start failed: \(error)")
            isMonitoring = false
        }
    }

    // MARK: - Audio Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)

        // Calculate RMS level
        var sum: Float = 0
        for i in 0..<frameCount {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrt(sum / Float(frameCount))

        // Apply simple low-pass filter for smoothing
        let smoothedLevel = rms * 10  // Scale for usability

        // Detect snoring band (30-300 Hz typical snoring range)
        // For simplicity, we use RMS level as proxy
        // In production, would use FFT to isolate snore frequency band

        DispatchQueue.main.async { [weak self] in
            self?.currentLevel = min(1.0, smoothedLevel)

            guard let sensitivity = self?.sensitivity else { return }

            let threshold = Float(1.0 - sensitivity) * 0.3

            if smoothedLevel < threshold * 0.3 {
                self?.snoreLevel = .none
            } else if smoothedLevel < threshold * 0.6 {
                self?.snoreLevel = .low
            } else if smoothedLevel < threshold {
                self?.snoreLevel = .medium
            } else {
                self?.snoreLevel = .high
            }
        }
    }
}
