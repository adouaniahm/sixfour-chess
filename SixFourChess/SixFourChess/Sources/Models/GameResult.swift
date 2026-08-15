import Foundation

/// Result of an in-progress game.
enum GameResult: Equatable, Codable {
    case checkmate(winner: PieceColor)
    case stalemate
    case drawByRepetition
    case drawByFiftyMoves
    case corruptedMatch  // 🆕 Match corrompu (erreur de reconstruction)

    var description: String {
        switch self {
        case .checkmate(let winner):
            let winnerName = winner == .white ? "result.checkmate.white".localized : "result.checkmate.black".localized
            return "result.checkmate".localized(with: winnerName)
        case .stalemate:
            return "result.stalemate".localized
        case .drawByRepetition:
            return "result.drawByRepetition".localized
        case .drawByFiftyMoves:
            return "result.drawByFiftyMoves".localized
        case .corruptedMatch:
            return "result.corruptedMatch".localized
        }
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case winner
    }

    private enum ResultType: String, Codable {
        case checkmate
        case stalemate
        case drawByRepetition
        case drawByFiftyMoves
        case corruptedMatch
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ResultType.self, forKey: .type)

        switch type {
        case .checkmate:
            let winner = try container.decode(PieceColor.self, forKey: .winner)
            self = .checkmate(winner: winner)
        case .stalemate:
            self = .stalemate
        case .drawByRepetition:
            self = .drawByRepetition
        case .drawByFiftyMoves:
            self = .drawByFiftyMoves
        case .corruptedMatch:
            self = .corruptedMatch
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .checkmate(let winner):
            try container.encode(ResultType.checkmate, forKey: .type)
            try container.encode(winner, forKey: .winner)
        case .stalemate:
            try container.encode(ResultType.stalemate, forKey: .type)
        case .drawByRepetition:
            try container.encode(ResultType.drawByRepetition, forKey: .type)
        case .drawByFiftyMoves:
            try container.encode(ResultType.drawByFiftyMoves, forKey: .type)
        case .corruptedMatch:
            try container.encode(ResultType.corruptedMatch, forKey: .type)
        }
    }
}
