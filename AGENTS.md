# SilentNight — Agent Operating Guide

## What This Is
SilentNight is a SwiftUI iOS app that plays brown noise (and other noise colors) and uses the phone's microphone to detect snoring in real-time, automatically adjusting the noise volume to cover it.

## Project Structure
```
SilentNight/
├── SilentNight/
│   ├── Sources/
│   │   ├── SilentNightApp.swift    # App entry point
│   │   ├── ContentView.swift       # Main tab container
│   │   ├── AudioEngine.swift       # Brown/pink/white/grey noise generator
│   │   ├── MicMonitor.swift        # Microphone snore detection
│   │   ├── NowPlayingView.swift    # Main playback screen
│   │   ├── NapTimerView.swift      # Nap timer
│   │   ├── WaveformView.swift      # Animated waveform visualization
│   │   └── SettingsView.swift      # Settings screen
│   ├── Resources/
│   │   └── Info.plist              # App config + mic permission
│   └── Tests/                      # Unit tests (add as needed)
└── AGENTS.md                        # This file
```

## Build & Run
```bash
cd ~/Projects/SilentNight

# Build for simulator
xcodebuild -scheme SilentNight -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Build for device (requires signing)
xcodebuild -scheme SilentNight -destination generic/platform=iOS build
```

## TestFlight Release
Follow apple-platform-operations skill for TestFlight signing/push.

## Pending Tasks (Fizzy #1158)

### Phase 1 — Project Setup [IN PROGRESS]
- [ ] Create Xcode project (.xcodeproj)
- [ ] Set up code signing (team ID: 6XV7UPKCH)
- [ ] Verify simulator build
- [ ] Verify device build

### Phase 2 — Core Implementation
- [ ] Wire up AudioEngine noise generation
- [ ] Wire up MicMonitor snore detection
- [ ] Implement auto-adjust volume feedback loop
- [ ] Nap timer with audio stop

### Phase 3 — Polish
- [ ] Liquid glass / premium design pass
- [ ] Smooth animations
- [ ] Haptic feedback
- [ ] Background audio mode

### Phase 4 — TestFlight
- [ ] Archive build
- [ ] Upload to TestFlight
- [ ] Invite Steve + Jared for QA
