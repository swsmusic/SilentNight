// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SilentNight",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SilentNight", targets: ["SilentNight"])
    ],
    targets: [
        .target(
            name: "SilentNight",
            path: "SilentNight",
            sources: [
                "SilentNightApp.swift",
                "ContentView.swift",
                "AudioEngine.swift",
                "MicMonitor.swift",
                "NowPlayingView.swift",
                "WaveformView.swift",
                "SettingsView.swift",
                "NapTimerView.swift"
            ]
        )
    ]
)
