import SwiftUI

/// View showing the full history of the current game.
struct CurrentGameHistoryView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let moveHistory: [String]  // Algebraic notation.
    var title: String = "game.history.full".localized
    var subtitle: String? = nil

    var body: some View {
        NavigationStack {
            List {
                if let subtitle {
                    Section {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(Array(moveHistory.enumerated().reversed()), id: \.offset) { index, moveNotation in
                    HStack {
                        Text("\(index + 1).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)

                        Text(moveNotation)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)

                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("a11y.moveEntry".localized(with: index + 1, moveNotation))
                }
            }
            .listStyle(.plain)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 32, height: 32)
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.secondaryTextColor(for: colorScheme))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("a11y.close".localized)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    CurrentGameHistoryView(moveHistory: [])
}
