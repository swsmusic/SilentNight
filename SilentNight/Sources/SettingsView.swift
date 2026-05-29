import SwiftUI

/// Settings screen for app preferences
struct SettingsView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var micMonitor: MicMonitor

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Microphone section
                    SettingsSection(title: "Microphone", icon: "mic.fill") {
                        VStack(spacing: 16) {
                            // Monitoring toggle
                            SettingsRow(label: "Monitor Snoring") {
                                Toggle("", isOn: Binding(
                                    get: { micMonitor.isMonitoring },
                                    set: { _ in micMonitor.toggleMonitoring() }
                                ))
                                .toggleStyle(SwitchToggleStyle(tint: Color(red: 1.0, green: 0.7, blue: 0.3)))
                            }

                            // Sensitivity slider
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Sensitivity")
                                        .font(.subheadline)
                                        .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                                    Spacer()
                                    Text(sensitivityLabel)
                                        .font(.subheadline)
                                        .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.3))
                                }
                                Slider(value: $micMonitor.sensitivity, in: 0...1)
                                    .accentColor(Color(red: 1.0, green: 0.7, blue: 0.3))
                            }
                        }
                    }

                    // Audio section
                    SettingsSection(title: "Audio", icon: "waveform") {
                        VStack(spacing: 16) {
                            SettingsRow(label: "Auto-adjust Volume") {
                                Toggle("", isOn: $audioEngine.isAutoMode)
                                    .toggleStyle(SwitchToggleStyle(tint: Color(red: 1.0, green: 0.7, blue: 0.3)))
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Default Volume")
                                        .font(.subheadline)
                                        .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                                    Spacer()
                                    Text("\(Int(audioEngine.volume * 100))%")
                                        .font(.subheadline)
                                        .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.3))
                                }
                                Slider(value: $audioEngine.volume, in: 0...1)
                                    .accentColor(Color(red: 1.0, green: 0.7, blue: 0.3))
                            }
                        }
                    }

                    // About section
                    SettingsSection(title: "About", icon: "info.circle") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SilentNight")
                                .font(.subheadline.bold())
                                .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.3))
                            Text("Brown noise generator with automatic snoring detection and adaptive volume.")
                                .font(.caption)
                                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                            Text("Version 1.0.0")
                                .font(.caption2)
                                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .background(Color(red: 0.05, green: 0.04, blue: 0.03))
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
                .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.3))

            VStack(spacing: 0) {
                content
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.12, green: 0.11, blue: 0.10))
            )
        }
    }
}

struct SettingsRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
            Spacer()
            content
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AudioEngine())
        .environmentObject(MicMonitor())
        .preferredColorScheme(.dark)
}
