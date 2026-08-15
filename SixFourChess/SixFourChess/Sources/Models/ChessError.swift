import Foundation

/// Chess-related errors.
enum ChessError: LocalizedError {
    case invalidMove(String)
    case corruptedMatch(String)

    var errorDescription: String? {
        switch self {
        case .invalidMove(let message):
            return "Invalid move: \(message)"
        case .corruptedMatch(let message):
            return "Corrupted match: \(message)"
        }
    }
}
