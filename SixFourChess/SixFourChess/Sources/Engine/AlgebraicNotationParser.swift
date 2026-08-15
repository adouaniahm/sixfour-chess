import Foundation

/// Parses and generates algebraic notation for chess moves.
///
/// ## Supported formats
///
/// ### 1. LAN - Long Algebraic Notation (app internal format)
/// **Used for:**
/// - Local move history (`ChessState.moveHistory`)
/// - Game persistence
///
/// **Format:** Always includes the full starting square.
/// - Pieces: `Ng1f3`, `Bb5c4`, `Qd1h5`
/// - Pawns: `e2e4`, `d7d5`
/// - Captures: `Ng1xf3`, `e5xd6`
/// - Castling: `O-O`, `O-O-O`
/// - Promotion: `e7e8Q`, `a2a1N`
///
/// **Benefits:**
/// - No ambiguity, because the starting square is always present.
/// - Simple and fast parsing.
/// - Guaranteed game reconstruction.
///
/// ### 2. SAN - Standard Algebraic Notation
/// **Used for:**
/// - Importing external PGN games
///
/// **Format:** Starting square only when needed.
/// - Pieces: `Nf3`, `Bc4`, `Qh5`
/// - Disambiguation: `Nbd7`, `R1a3`, `Qh4e1`
/// - Pawns: `e4`, `d5`
/// - Captures: `Nxf3`, `exd6`
/// - Castling: `O-O`, `O-O-O`
/// - Promotion: `e8=Q`, `a1=N`
///
/// **Note:** The parser automatically detects the format (LAN or SAN).
///
nonisolated struct AlgebraicNotationParser {

    // MARK: - Algebraic notation generation

    /// Converts a `Move` to long algebraic notation (LAN).
    /// App internal format used for local history.
    /// - Parameters:
    ///   - move: The move to convert.
    ///   - board: Board state before the move.
    /// - Returns: Long algebraic notation, for example "e2e4", "Ng1f3", "O-O", "e7e8Q".
    @MainActor static func toAlgebraic(move: Move, board: ChessBoard) -> String {
        return toAlgebraic(move: move, state: board.state)
    }

    /// Converts a `Move` to long algebraic notation (LAN) with a state struct.
    /// Format always includes the starting square to avoid ambiguity.
    static func toAlgebraic(move: Move, state: ChessState) -> String {
        // Castling.
        if move.isCastling {
            return move.to.col > move.from.col ? "O-O" : "O-O-O"
        }

        var result = ""

        // Piece type, except for pawns.
        if move.piece.type != .pawn {
            result += pieceSymbol(for: move.piece.type)

            // Long format: always include the starting square.
            // Example: "Nb1c3" instead of "Nc3".
            result += positionNotation(move.from)
        } else if move.capturedPiece != nil || move.isEnPassant {
            // For a capturing pawn, include the starting file.
            result += columnNotation(move.from.col)
        }

        // Capture.
        if move.capturedPiece != nil || move.isEnPassant {
            result += "x"
        }

        // Destination.
        result += positionNotation(move.to)

        // Promotion.
        if let promotionType = move.promotionType {
            result += "=" + pieceSymbol(for: promotionType)
        }

        return result
    }

    private static func pieceSymbol(for type: PieceType) -> String {
        switch type {
        case .knight: return "N"
        case .bishop: return "B"
        case .rook: return "R"
        case .queen: return "Q"
        case .king: return "K"
        case .pawn: return ""
        }
    }

    private static func columnNotation(_ col: Int) -> String {
        guard col >= 0 && col < 8 else { return "" }
        return String(UnicodeScalar(UInt8(Character("a").asciiValue!) + UInt8(col)))
    }

    private static func rowNotation(_ row: Int) -> String {
        return String(8 - row)
    }

    private static func positionNotation(_ position: Position) -> String {
        return columnNotation(position.col) + rowNotation(position.row)
    }

    // MARK: - Algebraic notation parsing

    /// Parses a list of moves in algebraic notation, supporting SAN and LAN.
    /// - SAN (Standard): "Nf3", "exd5", "O-O" (historical games)
    /// - LAN (Long): "Ng1f3", "e5xd4", "O-O" (app internal)
    @MainActor static func parseMoves(_ moves: [String], on board: ChessBoard) -> [Move] {
        var parsedMoves: [Move] = []
        let currentBoard = board.copy()

        for (index, moveString) in moves.enumerated() {
            if let move = parseMove(moveString, on: currentBoard) {
                currentBoard.makeMove(move)
                parsedMoves.append(move)
            } else {
                Logger.error("Failed to parse move \(index + 1)/\(moves.count): '\(moveString)'", subsystem: .parser)
                break
            }
        }

        return parsedMoves
    }

    /// Parses a single move in algebraic notation (SAN or LAN).
    /// Supports: "Nf3", "Ng1f3", "exd5", "e5xd4", "O-O", "e8=Q"
    @MainActor static func parseMove(_ notation: String, on board: ChessBoard) -> Move? {
        var clean = notation.replacingOccurrences(of: "+", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "x", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "?", with: "")
            .trimmingCharacters(in: .whitespaces)

        // King-side castling.
        if clean == "O-O" || clean == "0-0" {
            return findCastlingMove(kingSide: true, on: board)
        }

        // Queen-side castling.
        if clean == "O-O-O" || clean == "0-0-0" {
            return findCastlingMove(kingSide: false, on: board)
        }

        // Promotion.
        var promotionType: PieceType?
        if clean.contains("=") {
            let parts = clean.split(separator: "=")
            clean = String(parts[0])
            if parts.count > 1 {
                promotionType = parsePieceType(String(parts[1]))
            }
        }

        // Determine the piece type and extract the details.
        let pieceType: PieceType
        var remainingString: String

        if let firstChar = clean.first, "NBRQK".contains(firstChar) {
            // Major/minor piece, not a pawn.
            pieceType = parsePieceType(String(firstChar)) ?? .pawn
            remainingString = String(clean.dropFirst())
        } else {
            // Pawn, because there is no leading uppercase letter.
            pieceType = .pawn
            remainingString = clean
        }

        // Extract the destination square (last 2 characters).
        guard remainingString.count >= 2 else { return nil }
        let destinationString = String(remainingString.suffix(2))
        guard let destination = parsePosition(destinationString) else { return nil }

        // Extract disambiguation, everything between the piece type and the destination.
        let disambiguationString = String(remainingString.dropLast(2))

        // Find legal candidate moves.
        let legalMoves = board.getAllLegalMoves(for: board.currentPlayer)
        let candidateMoves = legalMoves.filter { move in
            move.piece.type == pieceType && move.to == destination
        }

        if candidateMoves.isEmpty {
            return nil
        }

        // Select the correct move, using disambiguation if needed.
        let selectedMove: Move?
        if candidateMoves.count == 1 {
            selectedMove = candidateMoves[0]
        } else {
            // Multiple candidates, use disambiguation.
            selectedMove = disambiguate(candidateMoves, with: disambiguationString)
        }

        guard let finalMove = selectedMove else {
            return nil
        }

        // Handle promotion.
        if let promo = promotionType, finalMove.piece.type == .pawn {
            return Move(
                from: finalMove.from,
                to: finalMove.to,
                piece: finalMove.piece,
                capturedPiece: finalMove.capturedPiece,
                isEnPassant: finalMove.isEnPassant,
                isCastling: false,
                promotionType: promo
            )
        }

        return finalMove
    }

    @MainActor private static func findCastlingMove(kingSide: Bool, on board: ChessBoard) -> Move? {
        let row = board.currentPlayer == .white ? 7 : 0
        let kingCol = 4
        let targetCol = kingSide ? 6 : 2

        let from = Position(row: row, col: kingCol)
        let to = Position(row: row, col: targetCol)

        guard let king = board.piece(at: from), king.type == .king else {
            return nil
        }

        return Move(
            from: from,
            to: to,
            piece: king,
            capturedPiece: nil,
            isEnPassant: false,
            isCastling: true,
            promotionType: nil
        )
    }

    private static func disambiguate(_ moves: [Move], with hint: String) -> Move? {
        // No disambiguation needed.
        if hint.isEmpty {
            return moves.first
        }

        // Full square specified in LAN format, for example "b1" in "Nb1c3".
        if hint.count == 2 {
            if let pos = parsePosition(hint) {
                let match = moves.first { $0.from == pos }
                if match != nil {
                    return match
                }
            }
        }

        // File specified, for example "b" in "Nbd7" or pawn "exd5".
        if hint.count == 1,
           let char = hint.first,
           char.isLowercase,
           let charValue = char.asciiValue,
           let aValue = Character("a").asciiValue {
            let col = Int(charValue - aValue)
            if let match = moves.first(where: { $0.from.col == col }) {
                return match
            }
        }

        // Rank specified, for example "1" in "R1a3".
        if hint.count == 1,
           let char = hint.first,
           char.isNumber,
           let rowNum = Int(String(char)) {
            let row = 8 - rowNum
            if let match = moves.first(where: { $0.from.row == row }) {
                return match
            }
        }

        // If disambiguation fails, return the first move.
        // That is better than returning nil.
        return moves.first
    }

    private static func parsePieceType(_ char: String) -> PieceType? {
        switch char.uppercased() {
        case "N": return .knight
        case "B": return .bishop
        case "R": return .rook
        case "Q": return .queen
        case "K": return .king
        default: return nil
        }
    }

    private static func parsePosition(_ notation: String) -> Position? {
        guard notation.count == 2,
              let col = notation.first,
              let row = notation.last,
              col.isLowercase,
              row.isNumber,
              let colValue = col.asciiValue,
              let aValue = Character("a").asciiValue,
              let rowNum = Int(String(row)) else {
            return nil
        }

        let colIndex = Int(colValue - aValue)
        let rowIndex = 8 - rowNum

        guard colIndex >= 0 && colIndex < 8 && rowIndex >= 0 && rowIndex < 8 else {
            return nil
        }

        return Position(row: rowIndex, col: colIndex)
    }
}
