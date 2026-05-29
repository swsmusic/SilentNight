import SwiftUI

@main
struct SilentNightApp: App {
    @StateObject private var audioEngine = AudioEngine()
    @StateObject private var micMonitor = MicMonitor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioEngine)
                .environmentObject(micMonitor)
                .preferredColorScheme(.dark)
        }
    }
}
