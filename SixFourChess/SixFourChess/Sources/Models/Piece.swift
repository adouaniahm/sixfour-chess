import Foundation

/// Represents chess piece types.
nonisolated enum PieceType: String, Codable, CaseIterable, Sendable {
    case pawn = "pawn"
    case knight = "knight"
    case bishop = "bishop"
    case rook = "rook"
    case queen = "queen"
    case king = "king"

    /// Material value in centipawns. `nonisolated` because this is a pure function
    /// on a Sendable value type - no shared state is accessed.
    nonisolated var value: Int {
        switch self {
        case .pawn: return 100
        case .knight: return 320
        case .bishop: return 330
        case .rook: return 500
        case .queen: return 900
        case .king: return 20000
        }
    }

    // Use filled symbols for all pieces.
    // SwiftUI applies the color.
    nonisolated var symbol: String {
        switch self {
        case .pawn:   return "♟"
        case .knight: return "♞"
        case .bishop: return "♝"
        case .rook:   return "♜"
        case .queen:  return "♛"
        case .king:   return "♚"
        }
    }
}

/// Represents a piece color.
nonisolated enum PieceColor: String, Codable, Sendable {
    case white
    case black

    /// Opponent color. `nonisolated` because this is a pure function on a Sendable enum.
    nonisolated var opposite: PieceColor {
        self == .white ? .black : .white
    }
}

/// Represents a chess piece.
nonisolated struct Piece: Codable, Equatable, Sendable, Hashable {
    let type: PieceType
    let color: PieceColor
    var hasMoved: Bool

    init(type: PieceType, color: PieceColor, hasMoved: Bool = false) {
        self.type = type
        self.color = color
        self.hasMoved = hasMoved
    }

    nonisolated var symbol: String {
        type.symbol
    }

    nonisolated var value: Int {
        type.value
    }
}
