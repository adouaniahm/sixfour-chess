import SwiftUI

enum PieceIconStyle {
    case flat
    case embossed3D
}

/// Central builder to render chess pieces in different visual styles.
struct PieceIconBuilder {
    static var sharedStyle: PieceIconStyle = .flat

    @ViewBuilder
    static func piece(type: PieceType, color: PieceColor, size: CGFloat) -> some View {
        switch sharedStyle {
        case .flat:
            ChessPieceShape(type: type)
                .fill(color == .white ? Color.white : Color.black)
                .frame(width: size, height: size)
                .shadow(color: color == .white ? .black : .white, radius: 1.5)
                .shadow(color: color == .white ? .black.opacity(0.5) : .white.opacity(0.5), radius: 2)

        case .embossed3D:
            // Warm, softly-shadowed gradient inspired by wooden/plastic 3D pieces
            let lightTop = color == .white ? Color(red: 0.99, green: 0.93, blue: 0.82) : Color(red: 0.25, green: 0.27, blue: 0.32)
            let lightMid = color == .white ? Color(red: 0.95, green: 0.85, blue: 0.70) : Color(red: 0.18, green: 0.20, blue: 0.24)
            let darkBase = color == .white ? Color(red: 0.82, green: 0.69, blue: 0.52) : Color(red: 0.10, green: 0.12, blue: 0.16)
            let outerShadow = color == .white ? Color.black.opacity(0.35) : Color.black.opacity(0.45)
            let innerHighlight = Color.white.opacity(0.55)

            ChessPieceShape(type: type)
                .fill(LinearGradient(
                    gradient: Gradient(colors: [lightTop, lightMid, darkBase]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: size, height: size)
                .overlay(
                    // Rim highlight to accentuate top edges
                    ChessPieceShape(type: type)
                        .stroke(innerHighlight, lineWidth: size * 0.04)
                        .blur(radius: 0.6)
                        .offset(x: -size * 0.04, y: -size * 0.04)
                        .mask(ChessPieceShape(type: type)
                            .stroke(style: StrokeStyle(lineWidth: size * 0.12)))
                )
                .overlay(
                    // Subtle inner shading to give depth
                    ChessPieceShape(type: type)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.black.opacity(0.0),
                                    Color.black.opacity(0.10),
                                    Color.black.opacity(0.18)
                                ]),
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            )
                        )
                        .blur(radius: 0.8)
                        .opacity(0.7)
                )
                .shadow(color: outerShadow, radius: size * 0.15, x: size * 0.06, y: size * 0.12)
                .shadow(color: outerShadow.opacity(0.35), radius: size * 0.08, x: 0, y: size * 0.05)
        }
    }
}
