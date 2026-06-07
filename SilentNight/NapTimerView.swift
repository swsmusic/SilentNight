import SwiftUI
import AVFoundation

/// Nap timer view for scheduling automatic stop
struct NapTimerView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @StateObject private var startChimePlayer = NapStartChimePlayer()
    @StateObject private var alarmPlayer = NapAlarmPlayer()

    @State private var selectedMinutes: Int = 30
    @State private var extendMinutes: Int = 10
    @State private var remainingSeconds: Int = 0
    @State private var totalTimerSeconds: Int = 0
    @State private var isActive = false
    @State private var isPaused = false
    @State private var isAlarmRinging = false
    @State private var timer: Timer?
    @State private var delayedNoiseStart: DispatchWorkItem?

    private let presetTimes = [10, 15, 20, 30, 45, 60, 90, 120]
    private let napStartChimeEnabled = true

    var body: some View {
        VStack(spacing: 20) {
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
            startChimePlayer.stop()
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

            Text(timerEndSummary)
                .font(.caption2.weight(.medium))
                .foregroundColor(Theme.accent.opacity(0.9))
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
        guard totalTimerSeconds > 0 else { return 0 }
        let elapsed = max(0, totalTimerSeconds - remainingSeconds)
        return min(1, max(0, Double(elapsed) / Double(totalTimerSeconds)))
    }

    private var timerEndSummary: String {
        if isPaused {
            return "End time will shift when you resume"
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let endDate = Date().addingTimeInterval(TimeInterval(max(0, remainingSeconds)))
        return "Ends around \(formatter.string(from: endDate))"
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
        VStack(spacing: 10) {
            extendTimerControls(context: .active)

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
        .padding(.bottom, 54)
    }

    private enum ExtendContext {
        case active
        case alarm
    }

    @ViewBuilder
    private func extendTimerControls(context: ExtendContext) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: { extendMinutes = max(5, extendMinutes - 5) }) {
                    Image(systemName: "minus")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 30, height: 30)
                }

                Text("\(extendMinutes)m")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Theme.accent)
                    .monospacedDigit()
                    .frame(minWidth: 36)

                Button(action: { extendMinutes = min(60, extendMinutes + 5) }) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 30, height: 30)
                }
            }
            .foregroundColor(Theme.textPrimary)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.cardStroke, lineWidth: 1))
            )

            Button(action: { extendNap(by: extendMinutes) }) {
                Label(context == .alarm ? "Snooze" : "Add time",
                      systemImage: context == .alarm ? "zzz" : "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Theme.accent.opacity(0.45), lineWidth: 1))
                    )
            }
        }
    }

    private var dismissAlarmButton: some View {
        VStack(spacing: 12) {
            extendTimerControls(context: .alarm)

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
        }
        .padding(.horizontal)
    }

    // MARK: - Timer Logic

    private func startTimer() {
        remainingSeconds = selectedMinutes * 60
        totalTimerSeconds = remainingSeconds
        isActive = true
        isPaused = false
        playStartChimeAndBeginNoiseIfNeeded()

        scheduleCountdownTimer()
    }

    private func playStartChimeAndBeginNoiseIfNeeded() {
        delayedNoiseStart?.cancel()
        delayedNoiseStart = nil

        guard napStartChimeEnabled else {
            if !audioEngine.isPlaying { audioEngine.play() }
            return
        }

        startChimePlayer.start()

        guard !audioEngine.isPlaying else { return }
        let workItem = DispatchWorkItem { [audioEngine] in
            audioEngine.play()
        }
        delayedNoiseStart = workItem
        // Let the five-note “rock-a-bye baby” pickup finish before the sleep-noise
        // fade rises underneath it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25, execute: workItem)
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

    private func extendNap(by minutes: Int) {
        let secondsToAdd = max(1, minutes) * 60

        if isAlarmRinging || alarmPlayer.isRinging {
            dismissAlarm()
            remainingSeconds = secondsToAdd
            totalTimerSeconds = secondsToAdd
            isActive = true
            isPaused = false
            audioEngine.play()
            scheduleCountdownTimer()
        } else {
            guard isActive else { return }
            remainingSeconds += secondsToAdd
            totalTimerSeconds += secondsToAdd
            if !isPaused && timer == nil {
                scheduleCountdownTimer()
            }
        }

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
        delayedNoiseStart?.cancel()
        delayedNoiseStart = nil
        startChimePlayer.stop()
        isActive = false
        isPaused = false
        remainingSeconds = 0
        totalTimerSeconds = 0
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

/// Gentle synthesized startup chime for the nap timer. Kept as its own small
/// player so the melody can be swapped or disabled without touching timer logic.
final class NapStartChimePlayer: ObservableObject {
    @Published private(set) var isPlaying = false

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
            player.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
                DispatchQueue.main.async {
                    self?.isPlaying = false
                }
            }
            player.volume = 0.38
            player.play()
            isPlaying = true
        } catch {
            print("NapStartChimePlayer failed to start: \(error)")
            isPlaying = false
        }
    }

    func stop() {
        player?.stop()
        engine?.stop()
        isPlaying = false
    }

    private func buildPipelineIfNeeded() {
        guard engine == nil else { return }

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let buffer = makeRockAByeBuffer(format: format)

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        self.engine = engine
        self.player = player
        self.buffer = buffer
    }

    private func makeRockAByeBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        struct Note {
            let start: TimeInterval
            let duration: TimeInterval
            let frequency: Double
        }

        // Five chimes only — one for each syllable in “rock-a-bye ba-by”.
        // Frequencies are kept explicit so swapping the phrase later is trivial.
        let notes = [
            Note(start: 0.00, duration: 0.20, frequency: 392.00), // G4 — Rock
            Note(start: 0.22, duration: 0.18, frequency: 392.00), // G4 — a
            Note(start: 0.42, duration: 0.24, frequency: 493.88), // B4 — bye
            Note(start: 0.70, duration: 0.22, frequency: 440.00), // A4 — ba
            Note(start: 0.96, duration: 0.34, frequency: 392.00)  // G4 — by
        ]

        let sampleRate = format.sampleRate
        let duration = (notes.map { $0.start + $0.duration }.max() ?? 0) + 0.18
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let channel = buffer.floatChannelData?[0] else { return buffer }

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            var sample: Double = 0

            for note in notes where time >= note.start && time < note.start + note.duration {
                let local = time - note.start
                let release = note.duration - local
                let attack = min(1.0, local / 0.035)
                let decay = min(1.0, max(0.0, release / 0.075))
                let envelope = attack * decay
                let fundamental = sin(2.0 * Double.pi * note.frequency * time)
                let softBell = 0.72 * fundamental + 0.18 * sin(2.0 * Double.pi * note.frequency * 2.0 * time)
                sample += softBell * envelope
            }

            channel[frame] = Float(sample * 0.20)
        }

        return buffer
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
