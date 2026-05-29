import SwiftUI

/// Nap timer view for scheduling automatic stop
struct NapTimerView: View {
    @EnvironmentObject var audioEngine: AudioEngine

    @State private var selectedMinutes: Int = 30
    @State private var remainingSeconds: Int = 0
    @State private var isActive = false
    @State private var timer: Timer?

    private let presetTimes = [10, 15, 20, 30, 45, 60, 90, 120]

    var body: some View {
        VStack(spacing: 32) {
            Text("Nap Timer")
                .font(.title2.bold())
                .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.3))
                .padding(.top, 24)

            Spacer()

            if isActive {
                timerDisplay
            } else {
                durationPicker
            }

            Spacer()

            if isActive {
                cancelButton
            } else {
                startButton
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .onDisappear { cancelTimer() }
        .onChange(of: audioEngine.isPlaying) { _, newValue in
            if !newValue && isActive {
                // Audio stopped externally, cancel timer
                cancelTimer()
            }
        }
    }

    // MARK: - Duration Picker

    private var durationPicker: some View {
        VStack(spacing: 16) {
            Text("Set timer duration")
                .font(.subheadline)
                .foregroundColor(.gray)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(presetTimes, id: \.self) { minutes in
                    Button(action: { selectedMinutes = minutes }) {
                        VStack(spacing: 4) {
                            Text("\(minutes)")
                                .font(.title3.bold())
                            Text("min")
                                .font(.caption2)
                        }
                        .foregroundColor(selectedMinutes == minutes ? .black : Color(red: 0.7, green: 0.7, blue: 0.7))
                        .frame(width: 60, height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedMinutes == minutes
                                      ? Color(red: 1.0, green: 0.7, blue: 0.3)
                                      : Color(red: 0.15, green: 0.14, blue: 0.13))
                        )
                    }
                }
            }
            .padding(.horizontal)

            // Custom stepper
            HStack {
                Text("Custom:")
                    .foregroundColor(.gray)
                Stepper(value: $selectedMinutes, in: 5...180, step: 5) {
                    Text("\(selectedMinutes) minutes")
                        .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.3))
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
                    .stroke(Color(red: 0.2, green: 0.2, blue: 0.2), lineWidth: 8)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color(red: 1.0, green: 0.7, blue: 0.3),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                VStack {
                    Text(formattedTime)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.3))
                    Text("remaining")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }

            Text("Noise will stop when timer ends")
                .font(.caption)
                .foregroundColor(.gray)
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
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 1.0, green: 0.7, blue: 0.3))
                )
        }
        .padding(.horizontal)
    }

    private var cancelButton: some View {
        Button(action: cancelTimer) {
            Text("Cancel Timer")
                .font(.headline)
                .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.3))
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 1.0, green: 0.7, blue: 0.3), lineWidth: 2)
                )
        }
        .padding(.horizontal)
    }

    // MARK: - Timer Logic

    private func startTimer() {
        remainingSeconds = selectedMinutes * 60
        isActive = true

        // Start audio if not already playing
        if !audioEngine.isPlaying {
            audioEngine.play()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else onTimerEnd()
        }
    }

    private func onTimerEnd() {
        cancelTimer()
        audioEngine.stop()

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    private func cancelTimer() {
        timer?.invalidate()
        timer = nil
        isActive = false
        remainingSeconds = 0
    }
}

#Preview {
    NapTimerView()
        .environmentObject(AudioEngine())
        .preferredColorScheme(.dark)
}
