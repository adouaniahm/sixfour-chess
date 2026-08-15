import SwiftUI

/// Custom view for displaying game help.
struct HintSheetView: View {
    @Environment(\.appReduxStore) private var appStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let hintText: String
    let suggestedMove: Move?
    let hintsRemaining: Int
    let onPlayMove: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.yellow)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("help.title".localized)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("help.subtitle".localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text("help.remaining".localized(with: hintsRemaining))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(parseHintSections().enumerated()), id: \.offset) { _, section in
                            VStack(alignment: .leading, spacing: 8) {
                                if !section.title.isEmpty {
                                    Text(section.title)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                        .accessibilityAddTraits(.isHeader)
                                }

                                ForEach(section.lines, id: \.self) { line in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•")
                                            .foregroundColor(.orange)
                                            .fontWeight(.bold)
                                            .accessibilityHidden(true)

                                        Text(line)
                                            .font(.body)
                                            .foregroundColor(.secondary)

                                        Spacer()
                                    }
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("action.help".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
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
            .safeAreaInset(edge: .bottom) {
                if suggestedMove != nil {
                    Button {
                        onPlayMove()
                        dismiss()
                    } label: {
                        Label("action.playMove".localized, systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .padding()
                    .background(.thinMaterial)
                }
            }
        }
        .accessibilityIdentifier("hintSheetView")
        .presentationDetents([.medium, .large])
    }

    private struct HintSection {
        let title: String
        let lines: [String]
    }

    private func parseHintSections() -> [HintSection] {
        var sections: [HintSection] = []

        let parts = hintText.components(separatedBy: "\n\n")

        for part in parts {
            let lines = part.components(separatedBy: "\n")

            if lines.isEmpty { continue }

            if lines.count == 1 {
                sections.append(HintSection(title: "", lines: [lines[0]]))
            } else {
                let title = lines[0]
                let content = Array(lines.dropFirst())
                sections.append(HintSection(title: title, lines: content))
            }
        }

        return sections
    }
}
