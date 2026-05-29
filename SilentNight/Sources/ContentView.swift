import SwiftUI

/// Main app view with tab-based navigation
struct ContentView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var micMonitor: MicMonitor

    var body: some View {
        ZStack {
            // Deep dark background
            Color(red: 0.05, green: 0.04, blue: 0.03)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                TabView {
                    NowPlayingView()
                        .tabItem {
                            Label("Play", systemImage: "waveform")
                        }

                    NapTimerView()
                        .tabItem {
                            Label("Timer", systemImage: "timer")
                        }

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape")
                        }
                }
                .accentColor(Color(red: 1.0, green: 0.7, blue: 0.3))
            }
        }
    }

    private var headerView: some View {
        VStack(spacing: 4) {
            Text("SilentNight")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.3))

            if micMonitor.isMonitoring {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Listening")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioEngine())
        .environmentObject(MicMonitor())
}
