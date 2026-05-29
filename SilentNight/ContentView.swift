import SwiftUI

/// Main app view with tab-based navigation
struct ContentView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var micMonitor: MicMonitor

    var body: some View {
        TabView {
            NavigationStack {
                NowPlayingView()
                    .background(backgroundLayer)
                    .navigationTitle("SilentNight")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            if micMonitor.isMonitoring {
                                listeningIndicator
                            }
                        }
                    }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem {
                Label("Play", systemImage: "waveform")
            }

            NavigationStack {
                NapTimerView()
                    .background(backgroundLayer)
                    .navigationTitle("Nap Timer")
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
            .tabItem {
                Label("Timer", systemImage: "timer")
            }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(Theme.accent)
    }

    private var listeningIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green)
                .frame(width: 7, height: 7)
                .shadow(color: .green.opacity(0.8), radius: 4)
            Text("Listening")
                .font(.caption2.weight(.medium))
                .foregroundColor(.green)
        }
        .transition(.opacity)
        .animation(.easeInOut, value: micMonitor.isMonitoring)
    }

    /// Deep night-sky background shared by the player and timer tabs.
    private var backgroundLayer: some View {
        ZStack {
            Theme.nightSky
                .ignoresSafeArea()

            RadialGradient(
                colors: [Theme.accent.opacity(0.16), .clear],
                center: .init(x: 0.5, y: 0.18),
                startRadius: 4,
                endRadius: 320
            )
            .ignoresSafeArea()
            .blendMode(.screen)
        }
    }
}

// MARK: - Design System

enum Theme {
    static let accent = Color(red: 1.0, green: 0.72, blue: 0.40)        // warm moonlit gold
    static let accentDeep = Color(red: 0.93, green: 0.54, blue: 0.26)
    static let textPrimary = Color(red: 0.96, green: 0.96, blue: 0.98)
    static let textSecondary = Color(red: 0.62, green: 0.64, blue: 0.72)
    static let cardStroke = Color.white.opacity(0.08)

    static var nightSky: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.08, blue: 0.16),
                Color(red: 0.04, green: 0.04, blue: 0.09),
                Color(red: 0.01, green: 0.01, blue: 0.03)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Frosted "liquid-glass" surface used for cards and pills.
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioEngine())
        .environmentObject(MicMonitor())
}
