import SwiftUI

/// View showing implemented and unimplemented chess rules (localized version).
struct RulesView: View {
    var body: some View {
        List {
            rulesContent
        }
        .navigationTitle("rules.title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var rulesContent: some View {
            Section {
                Text("rules.intro".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Section("rules.implemented".localized) {
                RuleRow(
                    title: "rule.basicMoves".localized,
                    description: "rule.basicMoves.desc".localized
                )

                RuleRow(
                    title: "rule.captures".localized,
                    description: "rule.captures.desc".localized
                )

                RuleRow(
                    title: "rule.enPassant".localized,
                    description: "rule.enPassant.desc".localized
                )

                RuleRow(
                    title: "rule.castling".localized,
                    description: "rule.castling.desc".localized
                )

                RuleRow(
                    title: "rule.promotion".localized,
                    description: "rule.promotion.desc".localized
                )

                RuleRow(
                    title: "rule.checkmate".localized,
                    description: "rule.checkmate.desc".localized
                )

                RuleRow(
                    title: "rule.stalemate".localized,
                    description: "rule.stalemate.desc".localized
                )

                RuleRow(
                    title: "rule.threefold".localized,
                    description: "rule.threefold.desc".localized
                )

                RuleRow(
                    title: "rule.fiftyMoves".localized,
                    description: "rule.fiftyMoves.desc".localized
                )

                RuleRow(
                    title: "rule.validation".localized,
                    description: "rule.validation.desc".localized
                )

                RuleRow(
                    title: "rule.history".localized,
                    description: "rule.history.desc".localized
                )

                RuleRow(
                    title: "rule.undo".localized,
                    description: "rule.undo.desc".localized
                )

            }

            Section("rule.bot.title".localized) {
                RuleRow(
                    title: "rule.bot.minimax".localized,
                    description: "rule.bot.minimax.desc".localized
                )

                RuleRow(
                    title: "rule.bot.levels".localized,
                    description: "rule.bot.levels.desc".localized
                )

                RuleRow(
                    title: "rule.bot.evaluation".localized,
                    description: "rule.bot.evaluation.desc".localized
                )
            }

            Section("rules.notImplemented".localized) {
                RuleRow(
                    title: "rule.insufficient".localized,
                    description: "rule.insufficient.desc".localized,
                    isImplemented: false
                )

                RuleRow(
                    title: "rule.clock".localized,
                    description: "rule.clock.desc".localized,
                    isImplemented: false
                )

                RuleRow(
                    title: "rule.pgn".localized,
                    description: "rule.pgn.desc".localized,
                    isImplemented: false
                )

                RuleRow(
                    title: "rule.endgame".localized,
                    description: "rule.endgame.desc".localized,
                    isImplemented: false
                )

                RuleRow(
                    title: "rule.analysis".localized,
                    description: "rule.analysis.desc".localized,
                    isImplemented: false
                )

                RuleRow(
                    title: "rule.tournament".localized,
                    description: "rule.tournament.desc".localized,
                    isImplemented: false
                )

                RuleRow(
                    title: "rule.puzzles".localized,
                    description: "rule.puzzles.desc".localized,
                    isImplemented: false
                )
            }
    }
}

/// Row displaying a rule.
struct RuleRow: View {
    let title: String
    let description: String
    var isImplemented: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.headline)

                if isImplemented {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                        .accessibilityLabel("a11y.implemented".localized)
                } else {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                        .accessibilityLabel("a11y.planned".localized)
                }
            }
            .accessibilityElement(children: .combine)

            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        RulesView()
    }
}
