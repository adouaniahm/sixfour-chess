import SwiftUI

struct PlayedGamesHistoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var games: [PlayedGameRecord] = []

    var body: some View {
        List {
            if games.isEmpty {
                ContentUnavailableView(
                    "history.played.empty.title".localized,
                    systemImage: "clock.arrow.circlepath",
                    description: Text("history.played.empty.message".localized)
                )
            } else {
                ForEach(games) { game in
                    NavigationLink {
                        PlayedGameReplayView(game: game)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(game.resultText)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryTextColor(for: colorScheme))

                            Text("history.played.summary".localized(with: game.moveCount, game.difficulty.localizedName, game.finishedAt.formatted(date: .abbreviated, time: .shortened)))
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryTextColor(for: colorScheme))
                        }
                        .padding(.vertical, 2)
                    }
                    .accessibilityIdentifier("playedGameRow_\(game.id)")
                }
            }
        }
        .navigationTitle("history.played.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            games = GamePersistenceController.shared.loadPlayedGames()
        }
    }
}
