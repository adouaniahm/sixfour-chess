//
//  GameControlBar.swift
//  SixFourChess
//
//  Compact control bar below the chessboard.
//  Replaces the old full-width buttons with icons and short labels.
//

import SwiftUI

/// Compact control bar displayed below the chessboard.
struct GameControlBar: View {
    @Environment(\.appReduxStore) private var appStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let gameState = appStore.state.gameState

        HStack(spacing: 10) {
            aiModeButtons(gameState: gameState)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.cardBackgroundColor(for: colorScheme).opacity(colorScheme == .dark ? 0.92 : 0.82),
                            AppTheme.cardBackgroundColor(for: colorScheme).opacity(colorScheme == .dark ? 0.72 : 0.68)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.28), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.10), radius: 18, y: 12)
        .padding(.horizontal, buttonHorizontalPadding)
        .padding(.bottom, buttonBottomPadding)
    }

    @ViewBuilder
    private func aiModeButtons(gameState: GameState) -> some View {
        controlButton(
            icon: "lightbulb.fill",
            label: "control.hint".localized(with: gameState.hintsRemaining),
            color: .orange,
            disabled: gameState.isThinking || gameState.isCalculatingHint || gameState.gameResult != nil || gameState.hintsRemaining == 0,
            accessibilityHint: "a11y.hint.getHelp".localized(with: gameState.hintsRemaining),
            identifier: "hintButton"
        ) {
            appStore.dispatch(AppAction.game(.requestHint))
        }

        controlButton(
            icon: "arrow.clockwise",
            label: "control.new".localized,
            color: AppTheme.accentColor(for: colorScheme),
            disabled: gameState.isThinking,
            accessibilityHint: "a11y.hint.newGame".localized,
            identifier: "newGameButton"
        ) {
            if gameState.gameResult != nil || gameState.board.moveHistory.isEmpty {
                appStore.dispatch(AppAction.game(.resetGame))
            } else {
                appStore.dispatch(AppAction.ui(.showAlert(.newGameConfirmation)))
            }
        }

        historyButton(gameState: gameState)
    }

    private func historyButton(gameState: GameState) -> some View {
        controlButton(
            icon: "list.number",
            label: "control.moves".localized,
            color: AppTheme.secondaryTextColor(for: colorScheme),
            disabled: gameState.board.moveHistory.isEmpty,
            accessibilityHint: "a11y.hint.history".localized,
            identifier: "historyButton"
        ) {
            appStore.dispatch(AppAction.ui(.showSheet(.history)))
        }
    }

    private func controlButton(
        icon: String,
        label: String,
        color: Color,
        disabled: Bool,
        accessibilityHint: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(disabled ? color.opacity(0.08) : color.opacity(0.16))
                        .frame(width: 44, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                }

                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .foregroundStyle(disabled ? color.opacity(0.35) : color)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 62)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(label)
        .accessibilityHint(accessibilityHint)
        .accessibilityIdentifier(identifier)
    }

    private var buttonHorizontalPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 40 : 16
    }

    private var buttonBottomPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 20 : 8
    }
}
