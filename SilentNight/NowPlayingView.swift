import SwiftUI

/// Now Playing screen - main noise player with controls
struct NowPlayingView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var micMonitor: MicMonitor

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 8)

            // Noise type selector
            noiseTypeSelector

            // Waveform visualization
            WaveformView(isPlaying: audioEngine.isPlaying, noiseType: audioEngine.noiseType)
                .frame(height: 120)

            // Volume control
            volumeControl

            Spacer(minLength: 4)

            // Play / Pause button
            PlayPauseButton(isPlaying: audioEngine.isPlaying) {
                audioEngine.togglePlayPause()
            }

            // Auto-adjust toggle
            autoAdjustToggle

            // Mic monitor status
            micStatusCard

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Noise Type Selector

    private var noiseTypeSelector: some View {
        VStack(spacing: 12) {
            Text("NOISE TYPE")
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .foregroundColor(Theme.textSecondary)

            HStack(spacing: 10) {
                ForEach(AudioEngine.NoiseType.allCases, id: \.self) { type in
                    let selected = audioEngine.noiseType == type
                    Button(action: { audioEngine.setNoiseType(type) }) {
                        Text(type.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(selected ? .black : Theme.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background {
                                if selected {
                                    Capsule().fill(Theme.accentGradient)
                                } else {
                                    Capsule().fill(.ultraThinMaterial)
                                        .overlay(Capsule().stroke(Theme.cardStroke, lineWidth: 1))
                                }
                            }
                    }
                    .animation(.easeInOut(duration: 0.18), value: selected)
                }
            }
        }
    }

    // MARK: - Volume Control

    private var volumeControl: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: systemVolumeIcon)
                    .foregroundColor(Theme.accent)
                    .frame(width: 22)
                Slider(value: $audioEngine.volume, in: 0...1)
                    .tint(Theme.accent)
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(Theme.accent)
            }

            Text("\(Int(audioEngine.volume * 100))%")
                .font(.caption.weight(.medium))
                .foregroundColor(Theme.textSecondary)
        }
    }

    private var systemVolumeIcon: String {
        if audioEngine.volume < 0.3 { return "speaker" }
        if audioEngine.volume < 0.7 { return "speaker.wave.1" }
        return "speaker.wave.2"
    }

    // MARK: - Auto Adjust

    private var autoAdjustToggle: some View {
        Button(action: { audioEngine.isAutoMode.toggle() }) {
            HStack {
                Image(systemName: audioEngine.isAutoMode ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(audioEngine.isAutoMode ? Theme.accent : Theme.textSecondary)
                Text("Auto-adjust for snoring")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassCard(cornerRadius: 14)
        }
    }

    // MARK: - Mic Status

    private var micStatusCard: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: micMonitor.isMonitoring ? "mic.fill" : "mic.slash.fill")
                    .foregroundColor(micMonitor.isMonitoring ? .green : Theme.textSecondary)
                Text(micMonitor.isMonitoring ? "Microphone Active" : "Microphone Off")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(micMonitor.isMonitoring ? .green : Theme.textSecondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { micMonitor.isMonitoring },
                    set: { _ in micMonitor.toggleMonitoring() }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
            }

            if micMonitor.isMonitoring {
                HStack {
                    Text("Snoring: \(micMonitor.snoreLevel.label)")
                        .font(.caption.weight(.medium))
                        .foregroundColor(levelColor)
                    Spacer()
                    LevelMeter(level: micMonitor.currentLevel)
                        .frame(width: 100, height: 8)
                }
            }
        }
        .padding()
        .glassCard()
    }

    private var levelColor: Color {
        let c = micMonitor.snoreLevel.color
        return Color(red: c.r, green: c.g, blue: c.b)
    }
}

// MARK: - Play/Pause Button

struct PlayPauseButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(Theme.accent.opacity(isPlaying ? 0.35 : 0.18))
                    .frame(width: 120, height: 120)
                    .blur(radius: 24)

                // Glass disc
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().stroke(Theme.cardStroke, lineWidth: 1))
                    .frame(width: 96, height: 96)

                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Theme.accentGradient)
                    .offset(x: isPlaying ? 0 : 3)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPlaying)
    }
}

// MARK: - Level Meter

struct LevelMeter: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))

                Capsule()
                    .fill(Theme.accentGradient)
                    .frame(width: geometry.size.width * CGFloat(min(1.0, level)))
            }
        }
    }
}

#Preview {
    NowPlayingView()
        .environmentObject(AudioEngine())
        .environmentObject(MicMonitor())
        .preferredColorScheme(.dark)
}
