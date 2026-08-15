import SwiftUI

/// Affiche les informations d'un joueur (humain ou bot)
struct PlayerInfoView: View {
    @Environment(\.colorScheme) private var colorScheme

    private struct CapturedPieceGroup: Identifiable {
        let type: PieceType
        let color: PieceColor
        let count: Int

        var id: PieceType { type }
    }

    let color: PieceColor
    let capturedPieces: [Piece]
    let isCurrentPlayer: Bool
    let isThinking: Bool
    let isBot: Bool
    let playerName: String?

    private var materialAdvantage: Int {
        capturedPieces.reduce(0) { $0 + $1.value }
    }

    private var capturedPieceGroups: [CapturedPieceGroup] {
        let order: [PieceType] = [.pawn, .knight, .bishop, .rook, .queen]
        var pieceCounts: [PieceType: Int] = [:]
        capturedPieces.forEach { pieceCounts[$0.type, default: 0] += 1 }

        let capturedColor = capturedPieces.first?.color ?? color.opposite
        return order.compactMap { type in
            guard let count = pieceCounts[type], count > 0 else { return nil }
            return CapturedPieceGroup(type: type, color: capturedColor, count: count)
        }
    }

    // MARK: - Accessibility helpers

    private var playerAccessibilityLabel: String {
        let colorText = color == .white ? "color.whites".localized : "color.blacks".localized
        if let name = playerName {
            return "\(name), \(colorText)"
        }
        let typeText = isBot ? "bot.label".localized : "player.label".localized
        return "\(colorText), \(typeText)"
    }

    private var playerAccessibilityValue: String {
        var parts: [String] = []

        if isCurrentPlayer {
            parts.append("a11y.yourTurn".localized)
        }

        if isThinking {
            parts.append("ui.thinking".localized)
        }

        if !capturedPieces.isEmpty {
            let capturedText = capturedPiecesDescription()
            parts.append("a11y.captured".localized(with: capturedText))
        }

        if materialAdvantage > 0 {
            parts.append("a11y.advantage".localized(with: materialAdvantage / 100))
        }

        return parts.joined(separator: ". ")
    }

    private func capturedPiecesDescription() -> String {
        let descriptions = capturedPieceGroups
            .map { group -> String in
                let pieceName: String
                switch group.type {
                case .pawn: pieceName = "piece.pawn".localized
                case .knight: pieceName = "piece.knight".localized
                case .bishop: pieceName = "piece.bishop".localized
                case .rook: pieceName = "piece.rook".localized
                case .queen: pieceName = "piece.queen".localized
                case .king: pieceName = "piece.king".localized
                }
                return group.count > 1 ? "\(group.count) \(pieceName)" : pieceName
            }

        return descriptions.joined(separator: ", ")
    }

    private var panelBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                AppTheme.cardBackgroundColor(for: colorScheme).opacity(colorScheme == .dark ? 0.88 : 0.78),
                AppTheme.cardBackgroundColor(for: colorScheme).opacity(colorScheme == .dark ? 0.70 : 0.60)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var panelBorderColor: Color {
        if isCurrentPlayer {
            return AppTheme.accentColor(for: colorScheme).opacity(0.55)
        }
        return colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    private var badgeFill: Color {
        isBot
            ? Color.orange.opacity(colorScheme == .dark ? 0.24 : 0.18)
            : AppTheme.accentColor(for: colorScheme).opacity(colorScheme == .dark ? 0.18 : 0.14)
    }

    private var badgeIconColor: Color {
        isBot ? .orange : AppTheme.accentColor(for: colorScheme)
    }

    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(badgeFill)
                    .frame(width: 40, height: 40)

                Image(systemName: isBot ? "cpu.fill" : "person.fill")
                    .foregroundColor(badgeIconColor)
                    .font(.system(size: 18))
            }
            .overlay {
                if isCurrentPlayer {
                    ZStack {
                        Circle()
                            .stroke(AppTheme.accentColor(for: colorScheme), lineWidth: 2.5)
                        Circle()
                            .fill(AppTheme.accentColor(for: colorScheme))
                            .frame(width: 10, height: 10)
                            .offset(x: 14, y: -14)
                    }
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                if let name = playerName {
                    Text(name)
                        .font(.headline)
                    Text(color == .white ? "color.whites".localized : "color.blacks".localized)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryTextColor(for: colorScheme))
                } else {
                    Text(color == .white ? "color.whites".localized : "color.blacks".localized)
                        .font(.caption)
                        .textCase(.uppercase)
                        .tracking(1.1)
                        .foregroundStyle(AppTheme.secondaryTextColor(for: colorScheme))

                    Text(isBot ? "bot.label".localized : "player.label".localized)
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryTextColor(for: colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .layoutPriority(1)
            .accessibilityHidden(true)

            Spacer()

            HStack(spacing: 5) {
                ForEach(capturedPieceGroups) { group in
                    capturedPieceGroupView(group)
                }
            }
            .frame(maxWidth: 150, alignment: .trailing)
            .accessibilityHidden(true)

            if materialAdvantage > 0 {
                Text("+\(materialAdvantage / 100)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryTextColor(for: colorScheme))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 28)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppTheme.lightSquareColor.opacity(colorScheme == .dark ? 0.22 : 0.50))
                    )
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(height: 68)
        .background(panelBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(panelBorderColor, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 16, y: 10)
        .overlay(alignment: .center) {
            if isThinking {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("ui.thinking".localized)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryTextColor(for: colorScheme))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(playerAccessibilityLabel)
        .accessibilityValue(playerAccessibilityValue)
    }

    @ViewBuilder
    private func capturedPieceGroupView(_ group: CapturedPieceGroup) -> some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.black.opacity(colorScheme == .dark ? 0.16 : 0.08))
                .overlay {
                    PieceIconBuilder.piece(type: group.type, color: group.color, size: 14)
                }
                .frame(width: 20, height: 20)

            if group.count > 1 {
                Text("\(group.count)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 14, minHeight: 14)
                    .padding(.horizontal, group.count > 9 ? 3 : 0)
                    .background(AppTheme.accentColor(for: colorScheme), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(AppTheme.cardBackgroundColor(for: colorScheme), lineWidth: 1.5)
                    }
                    .offset(x: 6, y: -6)
            }
        }
        .frame(width: 25, height: 24)
    }
}
