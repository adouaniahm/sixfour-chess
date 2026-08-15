import SwiftUI

/// SixFour app theme, based on a chessboard wood palette.
enum AppTheme {
    static let lightSquareColor = Color(red: 0.93, green: 0.85, blue: 0.71)
    static let darkSquareColor = Color(red: 0.71, green: 0.53, blue: 0.39)
    static let darkModeLightSquareColor = Color(red: 0.46, green: 0.35, blue: 0.27)
    static let darkModeDarkSquareColor = Color(red: 0.22, green: 0.17, blue: 0.13)

    /// Adaptive primary background color.
    static func backgroundColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 30/255, green: 30/255, blue: 35/255)
            : Color(red: 250/255, green: 247/255, blue: 240/255)
    }

    /// Adaptive primary text color.
    static func primaryTextColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 220/255, green: 215/255, blue: 210/255)
            : Color(red: 51/255, green: 40/255, blue: 34/255)
    }

    /// Adaptive secondary text color.
    static func secondaryTextColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 160/255, green: 155/255, blue: 150/255)
            : Color(red: 100/255, green: 90/255, blue: 80/255)
    }

    /// Adaptive accent color based on the wood palette.
    static func accentColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 180/255, green: 140/255, blue: 100/255) // Light wood tone.
            : Color(red: 139/255, green: 90/255, blue: 43/255)   // Dark wood tone.
    }

    /// Main background gradient for the game screen.
    static func backgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        colorScheme == .dark
            ? LinearGradient(
                colors: [
                    darkModeDarkSquareColor,
                    darkModeLightSquareColor,
                    darkModeDarkSquareColor.opacity(0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            : LinearGradient(
                colors: [
                    darkSquareColor.opacity(0.92),
                    lightSquareColor,
                    darkSquareColor.opacity(0.82)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
    }

    /// Adaptive card background color.
    static func cardBackgroundColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 40/255, green: 40/255, blue: 45/255)
            : Color(red: 255/255, green: 253/255, blue: 250/255)
    }
}

// MARK: - View helpers

extension View {
    func themedBackground(_ colorScheme: ColorScheme) -> some View {
        self.background(AppTheme.backgroundColor(for: colorScheme))
    }

    func themedForeground(_ colorScheme: ColorScheme, secondary: Bool = false) -> some View {
        self.foregroundStyle(
            secondary
                ? AppTheme.secondaryTextColor(for: colorScheme)
                : AppTheme.primaryTextColor(for: colorScheme)
        )
    }

    func themedAccent(_ colorScheme: ColorScheme) -> some View {
        self.foregroundStyle(AppTheme.accentColor(for: colorScheme))
    }
}
