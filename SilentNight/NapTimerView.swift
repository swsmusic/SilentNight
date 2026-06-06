import SwiftUI
import AVFoundation

/// Nap timer view for scheduling automatic stop
struct NapTimerView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @StateObject private var alarmPlayer = NapAlarmPlayer()

    @State private var selectedMinutes: Int = 30
    @State private var remainingSeconds: Int = 0
    @State private var isActive = false
    @State private var isPaused = false
    @State private var isAlarmRinging = false
    @State private var timer: Timer?

    private let presetTimes = [10, 15, 20, 30, 45, 60, 90, 120]

    var body: some View {
        VStack(spacing: 32) {
            Text("Nap Timer")
                .font(.title2.bold())
                .foregroundStyle(Theme.accentGradient)
                .padding(.top, 24)

            Spacer()

            if isAlarmRinging {
                alarmDisplay
            } else if isActive {
                timerDisplay
            } else {
                durationPicker
            }

            Spacer()

            if isAlarmRinging {
                dismissAlarmButton
            } else if isActive {
                activeControls
            } else {
                startButton
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .onDisappear {
            cancelTimer()
            dismissAlarm()
        }
        .onChange(of: audioEngine.isPlaying) { _, newValue in
            if !newValue && isActive && !isPaused {
                // Audio stopped externally, cancel timer. Pausing the nap timer
                // intentionally pauses audio without discarding remaining time.
                cancelTimer()
            }
        }
    }

    // MARK: - Duration Picker

    private var durationPicker: some View {
        VStack(spacing: 16) {
            Text("Set timer duration")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(presetTimes, id: \.self) { minutes in
                    let selected = selectedMinutes == minutes
                    Button(action: { selectedMinutes = minutes }) {
                        VStack(spacing: 4) {
                            Text("\(minutes)")
                                .font(.title3.bold())
                            Text("min")
                                .font(.caption2)
                        }
                        .foregroundColor(selected ? .black : Theme.textPrimary)
                        .frame(width: 60, height: 60)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.accentGradient)
                            } else {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Theme.cardStroke, lineWidth: 1))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)

            // Custom stepper
            HStack {
                Text("Custom:")
                    .foregroundColor(Theme.textSecondary)
                Stepper(value: $selectedMinutes, in: 5...180, step: 5) {
                    Text("\(selectedMinutes) minutes")
                        .foregroundColor(Theme.accent)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Timer Display

    private var timerDisplay: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 10)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Theme.accentGradient,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Theme.accent.opacity(0.5), radius: 8)
                    .animation(.linear(duration: 1), value: progress)

                VStack(spacing: 6) {
                    Text(formattedTime)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Text(isPaused ? "paused" : "remaining")
                        .font(.subheadline.weight(isPaused ? .semibold : .regular))
                        .foregroundColor(isPaused ? Theme.accent : Theme.textSecondary)
                }
            }
            .opacity(isPaused ? 0.82 : 1.0)

            Text(isPaused ? "Timer and noise are paused — resume when you’re ready" : "Noise will stop when timer ends")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var alarmDisplay: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.16))
                    .frame(width: 200, height: 200)
                    .blur(radius: 8)

                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().stroke(Theme.accent.opacity(0.55), lineWidth: 2))
                    .frame(width: 172, height: 172)

                VStack(spacing: 12) {
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Theme.accentGradient)
                    Text("Timer done")
                        .font(.title2.bold())
                        .foregroundColor(Theme.textPrimary)
                    Text("Alarm is ringing")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .symbolEffect(.pulse, value: isAlarmRinging)

            Text("Sleep noise faded out first. Tap dismiss when you’re awake.")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var progress: Double {
        let total = selectedMinutes * 60
        guard total > 0 else { return 0 }
        return Double(total - remainingSeconds) / Double(total)
    }

    private var formattedTime: String {
        let h = remainingSeconds / 3600
        let m = (remainingSeconds % 3600) / 60
        let s = remainingSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Buttons

    private var startButton: some View {
        Button(action: startTimer) {
            Text("Start Timer")
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.accentGradient)
                )
        }
        .padding(.horizontal)
    }

    private var activeControls: some View {
        VStack(spacing: 12) {
            Button(action: isPaused ? resumeTimer : pauseTimer) {
                Label(isPaused ? "Resume Timer" : "Pause Timer",
                      systemImage: isPaused ? "play.fill" : "pause.fill")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.accentGradient)
                    )
            }

            Button(action: cancelTimerAndStopAudio) {
                Text("Cancel Timer")
                    .font(.headline)
                    .foregroundColor(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.accent, lineWidth: 2)
                    )
            }
        }
        .padding(.horizontal)
    }

    private var dismissAlarmButton: some View {
        Button(action: dismissAlarm) {
            Label("Dismiss Alarm", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.accentGradient)
                )
        }
        .padding(.horizontal)
    }

    // MARK: - Timer Logic

    private func startTimer() {
        remainingSeconds = selectedMinutes * 60
        isActive = true
        isPaused = false

        // Start audio if not already playing
        if !audioEngine.isPlaying {
            audioEngine.play()
        }

        scheduleCountdownTimer()
    }

    private func scheduleCountdownTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard !isPaused else { return }
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                onTimerEnd()
            }
        }
    }

    private func pauseTimer() {
        guard isActive, !isPaused else { return }
        isPaused = true
        timer?.invalidate()
        timer = nil
        audioEngine.pause()

        let impact = UIImpactFeedbackGenerator(style: .soft)
        impact.impactOccurred()
    }

    private func resumeTimer() {
        guard isActive, isPaused, remainingSeconds > 0 else { return }
        isPaused = false
        audioEngine.play()
        scheduleCountdownTimer()

        let impact = UIImpactFeedbackGenerator(style: .soft)
        impact.impactOccurred()
    }

    private func onTimerEnd() {
        timer?.invalidate()
        timer = nil
        isActive = false
        isPaused = false
        remainingSeconds = 0
        isAlarmRinging = true
        audioEngine.stop()

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Let the sleep noise fade out before the alarm starts so the end state is
        // clear and not a harsh overlap of two sounds.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            guard isAlarmRinging else { return }
            alarmPlayer.start()
        }
    }

    /// Invalidates the timer state only — used by onDisappear so navigating
    /// away from the Timer tab doesn't kill noise the user wants to keep playing.
    private func cancelTimer() {
        timer?.invalidate()
        timer = nil
        isActive = false
        isPaused = false
        remainingSeconds = 0
    }

    /// User explicitly tapped Cancel — kill timer AND stop the noise it started.
    private func cancelTimerAndStopAudio() {
        cancelTimer()
        audioEngine.stop()
    }

    private func dismissAlarm() {
        guard isAlarmRinging || alarmPlayer.isRinging else { return }
        isAlarmRinging = false
        alarmPlayer.stop()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

/// Small synthesized alarm used by the nap timer. It avoids bundled assets while
/// giving the user a real, repeatable, dismissible sound that respects the
/// current iOS audio session/output volume.
final class NapAlarmPlayer: ObservableObject {
    @Published private(set) var isRinging = false

    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var buffer: AVAudioPCMBuffer?

    func start() {
        stop()
        buildPipelineIfNeeded()
        guard let engine, let player, let buffer else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord,
                                    mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try session.setActive(true, options: [])

            if !engine.isRunning { try engine.start() }
            player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            player.volume = 0.72
            player.play()
            isRinging = true
        } catch {
            print("NapAlarmPlayer failed to start: \(error)")
            isRinging = false
        }
    }

    func stop() {
        player?.stop()
        engine?.stop()
        isRinging = false
    }

    private func buildPipelineIfNeeded() {
        guard engine == nil else { return }

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let buffer = makeAlarmBuffer(format: format)

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        self.engine = engine
        self.player = player
        self.buffer = buffer
    }

    private func makeAlarmBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let duration: TimeInterval = 1.6
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let channel = buffer.floatChannelData?[0] else { return buffer }

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let cyclePosition = time.truncatingRemainder(dividingBy: duration)
            let frequency: Double
            let amplitude: Float

            switch cyclePosition {
            case 0.00..<0.28:
                frequency = 784   // G5
                amplitude = 0.34
            case 0.36..<0.64:
                frequency = 988   // B5
                amplitude = 0.30
            case 0.78..<1.06:
                frequency = 880   // A5
                amplitude = 0.26
            default:
                frequency = 0
                amplitude = 0
            }

            guard frequency > 0 else {
                channel[frame] = 0
                continue
            }

            let localToneTime = cyclePosition.truncatingRemainder(dividingBy: 0.36)
            let envelope = min(1.0, localToneTime / 0.025) * min(1.0, max(0.0, (0.30 - localToneTime) / 0.04))
            let sine = sin(2.0 * Double.pi * frequency * time)
            channel[frame] = Float(sine) * amplitude * Float(envelope)
        }

        return buffer
    }
}

#Preview {
    NapTimerView()
        .environmentObject(AudioEngine())
        .preferredColorScheme(.dark)
}
