import SwiftUI
import AVFoundation

/// Splash screen view with a logo animation.
struct SplashScreenView: View {
    @State private var logoOffset: CGFloat = -300
    @State private var logoOpacity: Double = 0
    @State private var showBaseline: Bool = false
    @State private var isAnimationComplete: Bool = false

    var onAnimationComplete: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            // Adaptive background based on the current color scheme.
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // SixFour logo.
                Image("SixFourLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .offset(y: logoOffset)
                    .opacity(logoOpacity)
                    .accessibilityLabel("app.name".localized)

                // Tagline.
                if showBaseline {
                    Text("app.tagline".localized)
                        .font(.system(.headline, design: .serif).weight(.light))
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    // Colors using the centralized theme.
    private var backgroundColor: Color {
        AppTheme.backgroundColor(for: colorScheme)
    }

    private var textColor: Color {
        AppTheme.primaryTextColor(for: colorScheme)
    }

    private func startAnimation() {
        if reduceMotion {
            // Skip animations and show the content immediately.
            logoOffset = 0
            logoOpacity = 1
            showBaseline = true
            playPieceSound()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isAnimationComplete = true
                onAnimationComplete()
            }
            return
        }

        // Animate the logo so it gently drops into place.
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7, blendDuration: 0)) {
            logoOffset = 0
            logoOpacity = 1
        }

        // Play the piece-drop sound.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            playPieceSound()
        }

        // Show the tagline after the logo.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeIn(duration: 0.5)) {
                showBaseline = true
            }
        }

        // Finish the animation and switch to the main screen.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            isAnimationComplete = true
            onAnimationComplete()
        }
    }

    private func playPieceSound() {
        // Play a piece-drop sound on the board.
        // Note: the sound must be added to the project resources.
        guard let soundURL = Bundle.main.url(forResource: "piece_drop", withExtension: "mp3") else {
            // If the file is missing, fall back to a system sound.
            AudioServicesPlaySystemSound(1104) // Soft tap sound.
            return
        }

        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer.volume = 0.3 // Soft volume.
            audioPlayer.play()
        } catch {
            Logger.warning("Error playing splash sound: \(error.localizedDescription)", subsystem: .ui)
        }
    }
}

#Preview {
    SplashScreenView {
        print("Animation completed")
    }
}
