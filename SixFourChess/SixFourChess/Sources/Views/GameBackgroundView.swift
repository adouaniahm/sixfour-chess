import SwiftUI

struct GameBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            GeometryReader { geo in
                centralGlow(in: geo)
                checkerPattern(in: geo)
                diagonalTexture(in: geo)
                edgeVignette
            }
            .ignoresSafeArea()
        }
    }

    private var lightPatternColor: Color {
        colorScheme == .dark
            ? AppTheme.lightSquareColor.opacity(0.06)
            : Color.white.opacity(0.18)
    }

    private var darkPatternColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.16)
            : AppTheme.darkSquareColor.opacity(0.10)
    }

    private var glowColor: Color {
        colorScheme == .dark
            ? AppTheme.lightSquareColor.opacity(0.16)
            : Color.white.opacity(0.55)
    }

    private var edgeVignette: some View {
        Rectangle()
            .fill(
                RadialGradient(
                    colors: [
                        .clear,
                        .clear,
                        Color.black.opacity(colorScheme == .dark ? 0.32 : 0.14)
                    ],
                    center: .center,
                    startRadius: 180,
                    endRadius: 780
                )
            )
            .blendMode(.multiply)
    }

    @ViewBuilder
    private func centralGlow(in geo: GeometryProxy) -> some View {
        Circle()
            .fill(glowColor)
            .frame(width: geo.size.width * 0.95, height: geo.size.width * 0.95)
            .blur(radius: 70)
            .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
    }

    @ViewBuilder
    private func checkerPattern(in geo: GeometryProxy) -> some View {
        let square = max(min(geo.size.width, geo.size.height) / 4.8, 90)

        ZStack {
            ForEach(-1..<6, id: \.self) { row in
                ForEach(-1..<6, id: \.self) { col in
                    Rectangle()
                        .fill((row + col).isMultiple(of: 2) ? lightPatternColor : darkPatternColor)
                        .frame(width: square, height: square)
                        .position(
                            x: CGFloat(col) * square + square / 2,
                            y: CGFloat(row) * square + square / 2
                        )
                }
            }
        }
        .rotationEffect(.degrees(-12))
        .scaleEffect(1.18)
        .blur(radius: colorScheme == .dark ? 0.5 : 0)
        .opacity(colorScheme == .dark ? 0.42 : 0.55)
        .mask {
            LinearGradient(
                colors: [
                    .black.opacity(0.2),
                    .black,
                    .black,
                    .black.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private func diagonalTexture(in geo: GeometryProxy) -> some View {
        Path { path in
            let spacing: CGFloat = 28
            let maxDimension = max(geo.size.width, geo.size.height) * 1.6

            stride(from: -maxDimension, through: maxDimension, by: spacing).forEach { offset in
                path.move(to: CGPoint(x: offset, y: 0))
                path.addLine(to: CGPoint(x: offset + maxDimension, y: maxDimension))
            }
        }
        .stroke(Color.white.opacity(colorScheme == .dark ? 0.03 : 0.10), lineWidth: 1)
        .blendMode(.softLight)
    }
}
