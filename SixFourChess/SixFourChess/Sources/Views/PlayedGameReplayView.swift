import SwiftUI

struct PlayedGameReplayView: View {
    @Environment(\.colorScheme) private var colorScheme

    let game: PlayedGameRecord

    @State private var currentPly = 0

    private var replayBoard: ChessBoard {
        let board = ChessBoard()
        for move in game.moveHistoryDetailed.prefix(currentPly) {
            _ = board.makeMove(move)
        }
        return board
    }

    private var currentMoveText: String {
        guard currentPly > 0, currentPly <= game.moveHistory.count else {
            return "history.replay.start".localized
        }
        return game.moveHistory[currentPly - 1]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryCard

                ChessBoardView(
                    board: replayBoard,
                    selectedPosition: nil,
                    availableMoves: [],
                    onSquareTapped: { _ in },
                    isFlipped: false,
                    animatingMove: nil,
                    onAnimationCompleted: nil,
                    accessibilityMode: .readOnly
                )
                .padding(.horizontal, 12)
                .allowsHitTesting(false)

                moveStatusCard

                replayControls
            }
            .padding()
        }
        .background(GameBackgroundView())
        .navigationTitle("history.played.detail.title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(game.resultText)
                .font(.headline)
                .foregroundStyle(AppTheme.primaryTextColor(for: colorScheme))

            Text("history.played.meta".localized(with: game.difficulty.localizedName, game.finishedAt.formatted(date: .abbreviated, time: .shortened)))
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryTextColor(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.cardBackgroundColor(for: colorScheme).opacity(colorScheme == .dark ? 0.88 : 0.82))
        )
    }

    private var moveStatusCard: some View {
        VStack(spacing: 6) {
            Text("history.replay.moveIndex".localized(with: currentPly, game.moveHistoryDetailed.count))
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryTextColor(for: colorScheme))

            Text(currentMoveText)
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .foregroundStyle(AppTheme.primaryTextColor(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.cardBackgroundColor(for: colorScheme).opacity(colorScheme == .dark ? 0.82 : 0.74))
        )
    }

    private var replayControls: some View {
        HStack(spacing: 12) {
            replayButton(
                icon: "backward.end.fill",
                label: "history.replay.first".localized,
                disabled: currentPly == 0
            ) {
                currentPly = 0
            }

            replayButton(
                icon: "chevron.backward",
                label: "history.replay.previous".localized,
                disabled: currentPly == 0
            ) {
                currentPly -= 1
            }

            replayButton(
                icon: "chevron.forward",
                label: "history.replay.next".localized,
                disabled: currentPly >= game.moveHistoryDetailed.count
            ) {
                currentPly += 1
            }

            replayButton(
                icon: "forward.end.fill",
                label: "history.replay.last".localized,
                disabled: currentPly >= game.moveHistoryDetailed.count
            ) {
                currentPly = game.moveHistoryDetailed.count
            }
        }
    }

    private func replayButton(
        icon: String,
        label: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(disabled ? AppTheme.secondaryTextColor(for: colorScheme).opacity(0.35) : AppTheme.accentColor(for: colorScheme))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.cardBackgroundColor(for: colorScheme).opacity(colorScheme == .dark ? 0.82 : 0.74))
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityIdentifier("replay_\(icon)")
    }
}
