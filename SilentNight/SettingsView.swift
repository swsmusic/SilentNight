import SwiftUI

/// Settings screen for app preferences
struct SettingsView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var micMonitor: MicMonitor

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Anti-Snore sensitivity (the on/off toggle lives on the Play screen)
                    SettingsSection(title: "Anti-Snore", icon: "waveform.badge.mic") {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Use the Anti-Snore toggle on the Play screen to turn on microphone monitoring. SilentNight will listen for snoring and automatically adjust the noise level.")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Sensitivity slider
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Sensitivity")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Text(sensitivityLabel)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(Theme.accent)
                                }
                                Slider(value: $micMonitor.sensitivity, in: 0...1)
                                    .tint(Theme.accent)
                            }
                        }
                    }

                    // Audio section
                    SettingsSection(title: "Audio", icon: "waveform") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Default Volume")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text("\(Int(audioEngine.volume * 100))%")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(Theme.accent)
                            }
                            Slider(value: $audioEngine.volume, in: 0...1)
                                .tint(Theme.accent)
                        }
                    }

                    // About section
                    SettingsSection(title: "About", icon: "info.circle") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SilentNight")
                                .font(.subheadline.bold())
                                .foregroundColor(Theme.accent)
                            Text("Brown noise generator with automatic snoring detection and adaptive volume.")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            Text("Version 1.0.0")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .background(Theme.nightSky.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
        }
    }

    private var sensitivityLabel: String {
        switch micMonitor.sensitivity {
        case 0..<0.25: return "Low"
        case 0.25..<0.5: return "Medium"
        case 0.5..<0.75: return "High"
        default: return "Max"
        }
    }
}

// MARK: - Settings Components

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(Theme.accent)

            VStack(spacing: 0) {
                content
            }
            .padding()
            .glassCard()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AudioEngine())
        .environmentObject(MicMonitor())
        .preferredColorScheme(.dark)
}
