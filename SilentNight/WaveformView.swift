import SwiftUI

/// Animated waveform visualization
struct WaveformView: View {
    let isPlaying: Bool
    let noiseType: AudioEngine.NoiseType

    @State private var phase: Double = 0
    @State private var timer: Timer?

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let width = size.width

            var path = Path()

            for x in stride(from: 0, to: width, by: 2) {
                let relX = x / width

                // Create organic waveform based on noise type
                let amplitude = noiseAmplitude(relX) * 40
                let frequency1 = noiseFrequency1
                let frequency2 = noiseFrequency2

                let y = midY + amplitude * sin(frequency1 * relX * .pi * 2 + phase)
                    + (amplitude * 0.5) * sin(frequency2 * relX * .pi * 2 + phase * 1.3)

                if x == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            let color = noiseType.color
            let baseColor = Color(red: color.r, green: color.g, blue: color.b)

            // Draw glow
            context.stroke(
                path,
                with: .color(baseColor.opacity(0.3)),
                lineWidth: 6
            )

            // Draw main line
            context.stroke(
                path,
                with: .color(baseColor),
                lineWidth: 2
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.07, blue: 0.06))
        )
        .onAppear { startAnimating() }
        .onDisappear { stopAnimating() }
        .onChange(of: isPlaying) { _, newValue in
            if newValue { startAnimating() } else { stopAnimating() }
        }
    }

    private var noiseAmplitude: (Double) -> Double {
        { 0.3 + 0.7 * sin($0 * .pi) }
    }

    private var noiseFrequency1: Double {
        switch noiseType {
        case .brown: return 3
        case .white: return 8
        case .pink: return 5
        case .grey: return 4
        }
    }

    private var noiseFrequency2: Double {
        switch noiseType {
        case .brown: return 7
        case .white: return 15
        case .pink: return 11
        case .grey: return 9
        }
    }

    private func startAnimating() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            phase += 0.08
        }
    }

    private func stopAnimating() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    WaveformView(isPlaying: true, noiseType: .brown)
        .frame(height: 120)
        .padding()
        .background(Color.black)
}
