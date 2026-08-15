import Foundation

enum FENError: LocalizedError {
    case invalidFormat
    case invalidBoard
    case invalidCharacter(Character)
    case invalidTurn
    case invalidEnPassant
    case invalidNumber
    case invalidCastling

    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "Invalid FEN: expected six space-separated fields."
        case .invalidBoard: return "Invalid FEN board layout."
        case .invalidCharacter(let char): return "Invalid FEN character: \(char)"
        case .invalidTurn: return "Invalid FEN active color."
        case .invalidEnPassant: return "Invalid FEN en passant square."
        case .invalidNumber: return "Invalid numeric component in FEN."
        case .invalidCastling: return "Invalid FEN castling rights."
        }
    }
}

extension ChessBoard {
    func toFEN() -> String {
        let boardPart = board.map { row -> String in
            var result = ""
            var emptyCount = 0
            for piece in row {
                if let piece = piece {
                    if emptyCount > 0 {
                        result.append(String(emptyCount))
                        emptyCount = 0
                    }
                    result.append(fenSymbol(for: piece))
                } else {
                    emptyCount += 1
                }
            }
            if emptyCount > 0 {
                result.append(String(emptyCount))
            }
            return result
        }.joined(separator: "/")

        let turnPart = currentPlayer == .white ? "w" : "b"
        let castlingPart = castlingRightsFEN()
        let enPassantPart = enPassantTarget?.notation ?? "-"
        let halfMovePart = String(halfMoveClock)
        let fullMovePart = String(fullMoveNumber)

        return [boardPart, turnPart, castlingPart, enPassantPart, halfMovePart, fullMovePart]
            .joined(separator: " ")
    }

    func loadFEN(_ fen: String) throws {
        let components = fen.split(separator: " ")
        guard components.count == 6 else { throw FENError.invalidFormat }

        let boardComponent = components[0]
        let turnComponent = components[1]
        let castlingComponent = components[2]
        let enPassantComponent = components[3]
        let halfMoveComponent = components[4]
        let fullMoveComponent = components[5]

        var newBoard = Array(repeating: Array(repeating: Piece?.none, count: 8), count: 8)
        let rows = boardComponent.split(separator: "/")
        guard rows.count == 8 else { throw FENError.invalidBoard }

        for (rowIndex, rowData) in rows.enumerated() {
            var column = 0
            for char in rowData {
                if let emptyCount = char.wholeNumberValue {
                    column += emptyCount
                } else {
                    guard column < 8 else { throw FENError.invalidBoard }
                    var piece = try piece(fromFEN: char)
                    piece.hasMoved = true
                    newBoard[rowIndex][column] = piece
                    column += 1
                }
            }
            if column != 8 {
                throw FENError.invalidBoard
            }
        }

        guard let turnChar = turnComponent.first, turnComponent.count == 1 else {
            throw FENError.invalidTurn
        }
        switch turnChar {
        case "w": currentPlayer = .white
        case "b": currentPlayer = .black
        default: throw FENError.invalidTurn
        }

        let castlingString = String(castlingComponent)
        isWhiteKingMoved = !castlingString.contains("K") && !castlingString.contains("Q")
        isWhiteRookRightMoved = !castlingString.contains("K")
        isWhiteRookLeftMoved = !castlingString.contains("Q")
        
        isBlackKingMoved = !castlingString.contains("k") && !castlingString.contains("q")
        isBlackRookRightMoved = !castlingString.contains("k")
        isBlackRookLeftMoved = !castlingString.contains("q")

        let enPassantString = String(enPassantComponent)
        if enPassantString == "-" {
            enPassantTarget = nil
        } else if let position = Position(notation: enPassantString) {
            enPassantTarget = position
        } else {
            throw FENError.invalidEnPassant
        }

        guard let halfMove = Int(halfMoveComponent),
              let fullMove = Int(fullMoveComponent),
              fullMove >= 1 else {
            throw FENError.invalidNumber
        }

        halfMoveClock = halfMove
        fullMoveNumber = fullMove

        applyHasMovedFlags(on: &newBoard)

        board = newBoard
        moveHistory.removeAll()
        capturedPieces.removeAll()
        capturedPieces = rebuildCapturedPieces(from: newBoard)
        lastMove = nil
    }

    convenience init(fen: String) throws {
        self.init()
        try loadFEN(fen)
    }

    private func fenSymbol(for piece: Piece) -> Character {
        let base: Character
        switch piece.type {
        case .pawn: base = "p"
        case .knight: base = "n"
        case .bishop: base = "b"
        case .rook: base = "r"
        case .queen: base = "q"
        case .king: base = "k"
        }
        if piece.color == .white {
            return String(base).uppercased().first ?? base
        }
        return base
    }

    private func castlingRightsFEN() -> String {
        var rights = ""
        if !isWhiteKingMoved {
            if !isWhiteRookRightMoved {
                rights.append("K")
            }
            if !isWhiteRookLeftMoved {
                rights.append("Q")
            }
        }
        if !isBlackKingMoved {
            if !isBlackRookRightMoved {
                rights.append("k")
            }
            if !isBlackRookLeftMoved {
                rights.append("q")
            }
        }
        return rights.isEmpty ? "-" : rights
    }

    private func piece(fromFEN symbol: Character) throws -> Piece {
        let isUppercase = symbol.isUppercase
        let color: PieceColor = isUppercase ? .white : .black
        guard let lower = String(symbol).lowercased().first else {
            throw FENError.invalidCharacter(symbol)
        }

        let type: PieceType
        switch lower {
        case "p": type = .pawn
        case "n": type = .knight
        case "b": type = .bishop
        case "r": type = .rook
        case "q": type = .queen
        case "k": type = .king
        default: throw FENError.invalidCharacter(symbol)
        }

        return Piece(type: type, color: color, hasMoved: true)
    }

    private func applyHasMovedFlags(on board: inout [[Piece?]]) {
        for row in 0..<8 {
            for col in 0..<8 {
                guard var piece = board[row][col] else { continue }
                switch (piece.type, piece.color) {
                case (.king, .white):
                    piece.hasMoved = isWhiteKingMoved
                case (.king, .black):
                    piece.hasMoved = isBlackKingMoved
                case (.rook, .white):
                    if row == 7 && col == 0 {
                        piece.hasMoved = isWhiteRookLeftMoved
                    } else if row == 7 && col == 7 {
                        piece.hasMoved = isWhiteRookRightMoved
                    } else {
                        piece.hasMoved = true
                    }
                case (.rook, .black):
                    if row == 0 && col == 0 {
                        piece.hasMoved = isBlackRookLeftMoved
                    } else if row == 0 && col == 7 {
                        piece.hasMoved = isBlackRookRightMoved
                    } else {
                        piece.hasMoved = true
                    }
                default:
                    piece.hasMoved = true
                }
                board[row][col] = piece
            }
        }
    }

    private func rebuildCapturedPieces(from board: [[Piece?]]) -> [Piece] {
        let initialCounts: [PieceType: Int] = [
            .pawn: 8, .knight: 2, .bishop: 2, .rook: 2, .queen: 1, .king: 1
        ]

        var currentCounts: [PieceColor: [PieceType: Int]] = [
            .white: [:],
            .black: [:]
        ]

        for row in board {
            for piece in row.compactMap({ $0 }) {
                currentCounts[piece.color, default: [:]][piece.type, default: 0] += 1
            }
        }

        func missingPieces(for color: PieceColor) -> [PieceType: Int] {
            var result: [PieceType: Int] = [:]
            let counts = currentCounts[color, default: [:]]

            // Calculate promotion offsets: any extra non-pawn pieces likely came from pawn promotions.
            let promotionOffset = PieceType.allCases.reduce(0) { partial, type in
                guard type != .pawn else { return partial }
                let extra = max(0, counts[type, default: 0] - (initialCounts[type] ?? 0))
                return partial + extra
            }

            for type in PieceType.allCases {
                let initial = initialCounts[type] ?? 0
                let current = counts[type, default: 0]
                if type == .pawn {
                    let rawMissing = max(0, initial - current)
                    let adjustedMissing = max(0, rawMissing - promotionOffset)
                    result[type] = adjustedMissing
                } else {
                    let missing = max(0, initial - current)
                    result[type] = missing
                }
            }

            return result
        }

        var rebuilt: [Piece] = []
        for color in [PieceColor.white, PieceColor.black] {
            let miss = missingPieces(for: color)
            for (type, count) in miss where count > 0 {
                for _ in 0..<count {
                    rebuilt.append(Piece(type: type, color: color, hasMoved: true))
                }
            }
        }
        return rebuilt
    }
}
