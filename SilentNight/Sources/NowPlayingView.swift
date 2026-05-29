import SwiftUI

/// Now Playing screen - main noise player with controls
struct NowPlayingView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var micMonitor: MicMonitor

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Noise type selector
            noiseTypeSelector

            Spacer()

            // Waveform visualization
            WaveformView(isPlaying: audioEngine.isPlaying, noiseType: audioEngine.noiseType)
                .frame(height: 120)

            // Volume control
            volumeControl

            Spacer()

            // Play / Pause button
            PlayPauseButton(isPlaying: audioEngine.isPlaying) {
                audioEngine.togglePlayPause()
            }

            // Auto-adjust toggle
            autoAdjustToggle

            // Mic monitor status
            micStatusCard

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Noise Type Selector

    private var noiseTypeSelector: some View {
        VStack(spacing: 12) {
            Text("Noise Type")
                .font(.subheadline)
                .foregroundColor(.gray)

            HStack(spacing: 12) {
                ForEach(AudioEngine.NoiseType.allCases, id: \.self) { type in
                    Button(action: { audioEngine.setNoiseType(type) }) {
                        Text(type.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(audioEngine.noiseType == type ? .black : Color(red: 0.7, green: 0.7, blue: 0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(audioEngine.noiseType == type
                                          ? Color(red: 1.0, green: 0.7, blue: 0.3)
                                          : Color(red: 0.15, green: 0.14, blue: 0.13))
                            )
                    }
                }
            }
        }
    }

    // MARK: - Volume Control

    private var volumeControl: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemVolumeIcon)
                    .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.3))
                Slider(value: $audioEngine.volume, in: 0...1)
                    .accentColor(Color(red: 1.0, green: 0.7, blue: 0.3))
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.3))
            }

            Text("\(Int(audioEngine.volume * 100))%")
                .font(.caption)
                .foregroundColor(.gray)
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
                    .foregroundColor(audioEngine.isAutoMode ? Color(red: 1.0, green: 0.7, blue: 0.3) : .gray)
                Text("Auto-adjust for snoring")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.12, green: 0.11, blue: 0.10))
            )
        }
    }

    // MARK: - Mic Status

    private var micStatusCard: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: micMonitor.isMonitoring ? "mic.fill" : "mic.slash.fill")
                    .foregroundColor(micMonitor.isMonitoring ? .green : .gray)
                Text(micMonitor.isMonitoring ? "Microphone Active" : "Microphone Off")
                    .font(.subheadline)
                    .foregroundColor(micMonitor.isMonitoring ? .green : .gray)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { micMonitor.isMonitoring },
                    set: { _ in micMonitor.toggleMonitoring() }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 1.0, green: 0.7, blue: 0.3)))
            }

            if micMonitor.isMonitoring {
                HStack {
                    Text("Snoring: \(micMonitor.snoreLevel.label)")
                        .font(.caption)
                        .foregroundColor(levelColor)
                    Spacer()
                    // Level meter
                    LevelMeter(level: micMonitor.currentLevel)
                        .frame(width: 100, height: 8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.12, green: 0.11, blue: 0.10))
        )
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
            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.3))
                .background(
                    Circle()
                        .fill(Color(red: 0.15, green: 0.14, blue: 0.13))
                        .frame(width: 88, height: 88)
                )
        }
    }
}

// MARK: - Level Meter

struct LevelMeter: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.2, green: 0.2, blue: 0.2))

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 1.0, green: 0.7, blue: 0.3))
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
