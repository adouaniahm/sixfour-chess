import Foundation

/// Represents the pure value-type state of the chess game.
/// This struct is used for efficient move generation and validation without object overhead.
nonisolated struct ChessState: Codable, Equatable, Sendable {
    var board: [[Piece?]]
    var currentPlayer: PieceColor
    var moveHistory: [String]  // Standard algebraic notation
    var moveHistoryDetailed: [Move]  // Detailed history for undo
    var capturedPieces: [Piece]
    var lastMove: Move?

    // Special states
    var enPassantTarget: Position?
    var isWhiteKingMoved: Bool = false
    var isBlackKingMoved: Bool = false
    var isWhiteRookLeftMoved: Bool = false
    var isWhiteRookRightMoved: Bool = false
    var isBlackRookLeftMoved: Bool = false
    var isBlackRookRightMoved: Bool = false

    // Move counters
    var halfMoveClock: Int = 0
    var fullMoveNumber: Int = 1

    // Position hash of the initial board (before any move) for threefold repetition detection
    var initialPositionHash: String = ""

    init() {
        self.board = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        self.currentPlayer = .white
        self.moveHistory = []
        self.moveHistoryDetailed = []
        self.capturedPieces = []
        self.lastMove = nil
        self.halfMoveClock = 0
        self.fullMoveNumber = 1
        setupInitialPosition()
    }

    // MARK: - Setup

    mutating func setupInitialPosition() {
        // Pawns
        for col in 0..<8 {
            board[1][col] = Piece(type: .pawn, color: .black)
            board[6][col] = Piece(type: .pawn, color: .white)
        }

        // Black pieces
        board[0][0] = Piece(type: .rook, color: .black)
        board[0][1] = Piece(type: .knight, color: .black)
        board[0][2] = Piece(type: .bishop, color: .black)
        board[0][3] = Piece(type: .queen, color: .black)
        board[0][4] = Piece(type: .king, color: .black)
        board[0][5] = Piece(type: .bishop, color: .black)
        board[0][6] = Piece(type: .knight, color: .black)
        board[0][7] = Piece(type: .rook, color: .black)

        // White pieces
        board[7][0] = Piece(type: .rook, color: .white)
        board[7][1] = Piece(type: .knight, color: .white)
        board[7][2] = Piece(type: .bishop, color: .white)
        board[7][3] = Piece(type: .queen, color: .white)
        board[7][4] = Piece(type: .king, color: .white)
        board[7][5] = Piece(type: .bishop, color: .white)
        board[7][6] = Piece(type: .knight, color: .white)
        board[7][7] = Piece(type: .rook, color: .white)

        // Store the initial position hash for threefold repetition detection
        initialPositionHash = getBoardHash()
    }

    // MARK: - Access

    func piece(at position: Position) -> Piece? {
        guard position.isValid else { return nil }
        return board[position.row][position.col]
    }

    mutating func setPiece(_ piece: Piece?, at position: Position) {
        guard position.isValid else { return }
        board[position.row][position.col] = piece
    }

    // MARK: - Game State

    func kingPosition(for color: PieceColor) -> Position? {
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = board[row][col],
                   piece.type == .king,
                   piece.color == color {
                    return Position(row: row, col: col)
                }
            }
        }
        return nil
    }

    func isInCheck(color: PieceColor) -> Bool {
        guard let kingPos = kingPosition(for: color) else { return false }

        // Check if any opponent piece can capture the king
        for row in 0..<8 {
            for col in 0..<8 {
                let pos = Position(row: row, col: col)
                if let piece = piece(at: pos),
                   piece.color == color.opposite {
                    // We use a static helper on MoveGenerator that accepts ChessState
                    let moves = MoveGenerator.generatePseudoLegalMoves(
                        for: piece,
                        at: pos,
                        on: self
                    )
                    if moves.contains(where: { $0.to == kingPos }) {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    func isCheckmate(for color: PieceColor) -> Bool {
        guard isInCheck(color: color) else { return false }
        return getAllLegalMoves(for: color).isEmpty
    }

    func isStalemate(for color: PieceColor) -> Bool {
        guard !isInCheck(color: color) else { return false }
        return getAllLegalMoves(for: color).isEmpty
    }

    func getAllLegalMoves(for color: PieceColor) -> [Move] {
        var allMoves: [Move] = []

        for row in 0..<8 {
            for col in 0..<8 {
                let pos = Position(row: row, col: col)
                if let piece = piece(at: pos), piece.color == color {
                    let moves = MoveGenerator.generateLegalMoves(
                        for: piece,
                        at: pos,
                        on: self
                    )
                    allMoves.append(contentsOf: moves)
                }
            }
        }

        return allMoves
    }

    // MARK: - Move Execution

    @discardableResult
    mutating func makeMove(_ move: Move) -> Bool {
        guard let piece = piece(at: move.from) else { return false }

        // --- Step 1: Capture pre-move state ---
        // Note: We need to overload toAlgebraic to accept ChessState
        let algebraic = AlgebraicNotationParser.toAlgebraic(move: move, state: self)
        let willUsePromotedPiece = capturedPieces.contains(where: { $0.type == move.promotionType && $0.color == piece.color })
        let preMoveState = (
            enPassantTarget: enPassantTarget,
            halfMoveClock: halfMoveClock,
            isWhiteKingMoved: isWhiteKingMoved,
            isBlackKingMoved: isBlackKingMoved,
            isWhiteRookLeftMoved: isWhiteRookLeftMoved,
            isWhiteRookRightMoved: isWhiteRookRightMoved,
            isBlackRookLeftMoved: isBlackRookLeftMoved,
            isBlackRookRightMoved: isBlackRookRightMoved
        )

        // --- Step 2: Apply move and update board state ---
        
        if piece.type == .pawn || move.capturedPiece != nil {
            halfMoveClock = 0
        } else {
            halfMoveClock += 1
        }

        if let captured = move.capturedPiece {
            capturedPieces.append(captured)
        }

        setPiece(nil, at: move.from)

        if let promotionType = move.promotionType {
            if let index = capturedPieces.firstIndex(where: { $0.type == promotionType && $0.color == piece.color }) {
                capturedPieces.remove(at: index)
            }
            let promotedPiece = Piece(type: promotionType, color: piece.color, hasMoved: true)
            setPiece(promotedPiece, at: move.to)
        } else {
            var movedPiece = piece
            movedPiece.hasMoved = true
            setPiece(movedPiece, at: move.to)
        }

        if move.isEnPassant {
            let captureRow = move.from.row
            setPiece(nil, at: Position(row: captureRow, col: move.to.col))
        }

        if move.isCastling {
            let row = move.from.row
            if move.to.col > move.from.col { // Kingside
                if let rook = self.piece(at: Position(row: row, col: 7)) {
                    setPiece(nil, at: Position(row: row, col: 7))
                    var movedRook = rook; movedRook.hasMoved = true
                    setPiece(movedRook, at: Position(row: row, col: 5))
                }
            } else { // Queenside
                if let rook = self.piece(at: Position(row: row, col: 0)) {
                    setPiece(nil, at: Position(row: row, col: 0))
                    var movedRook = rook; movedRook.hasMoved = true
                    setPiece(movedRook, at: Position(row: row, col: 3))
                }
            }
        }

        updateMoveFlags(for: piece, from: move.from)

        if piece.type == .pawn && abs(move.to.row - move.from.row) == 2 {
            enPassantTarget = Position(row: (move.from.row + move.to.row) / 2, col: move.from.col)
        } else {
            enPassantTarget = nil
        }
        
        currentPlayer = currentPlayer.opposite
        if piece.color == .black {
            fullMoveNumber += 1
        }

        // --- Step 3: Capture post-move state and create detailed move object ---
        
        let positionHash = getBoardHash()

        let moveWithState = Move(
            from: move.from,
            to: move.to,
            piece: move.piece,
            capturedPiece: move.capturedPiece,
            isEnPassant: move.isEnPassant,
            isCastling: move.isCastling,
            promotionType: move.promotionType,
            promotionUsedCapturedPiece: willUsePromotedPiece,
            positionHash: positionHash,
            previousEnPassantTarget: preMoveState.enPassantTarget,
            previousHalfMoveClock: preMoveState.halfMoveClock,
            previousWhiteKingMoved: preMoveState.isWhiteKingMoved,
            previousBlackKingMoved: preMoveState.isBlackKingMoved,
            previousWhiteRookLeftMoved: preMoveState.isWhiteRookLeftMoved,
            previousWhiteRookRightMoved: preMoveState.isWhiteRookRightMoved,
            previousBlackRookLeftMoved: preMoveState.isBlackRookLeftMoved,
            previousBlackRookRightMoved: preMoveState.isBlackRookRightMoved
        )
        
        moveHistory.append(algebraic)
        moveHistoryDetailed.append(moveWithState)
        lastMove = moveWithState

        return true
    }

    private mutating func updateMoveFlags(for piece: Piece, from position: Position) {
        if piece.type == .king {
            if piece.color == .white {
                isWhiteKingMoved = true
            } else {
                isBlackKingMoved = true
            }
        } else if piece.type == .rook {
            if piece.color == .white {
                if position.col == 0 {
                    isWhiteRookLeftMoved = true
                } else if position.col == 7 {
                    isWhiteRookRightMoved = true
                }
            } else {
                if position.col == 0 {
                    isBlackRookLeftMoved = true
                } else if position.col == 7 {
                    isBlackRookRightMoved = true
                }
            }
        }
    }

    mutating func undoLastMove() {
        guard let move = moveHistoryDetailed.popLast() else { return }

        if !moveHistory.isEmpty {
            moveHistory.removeLast()
        }

        currentPlayer = currentPlayer.opposite

        enPassantTarget = move.previousEnPassantTarget
        halfMoveClock = move.previousHalfMoveClock
        isWhiteKingMoved = move.previousWhiteKingMoved
        isBlackKingMoved = move.previousBlackKingMoved
        isWhiteRookLeftMoved = move.previousWhiteRookLeftMoved
        isWhiteRookRightMoved = move.previousWhiteRookRightMoved
        isBlackRookLeftMoved = move.previousBlackRookLeftMoved
        isBlackRookRightMoved = move.previousBlackRookRightMoved

        if let promotionType = move.promotionType {
            setPiece(move.piece, at: move.from)
            if move.promotionUsedCapturedPiece {
                let restoredPiece = Piece(type: promotionType, color: move.piece.color, hasMoved: false)
                capturedPieces.append(restoredPiece)
            }
        } else {
            setPiece(move.piece, at: move.from)
        }

        if move.isEnPassant {
            setPiece(nil, at: move.to)
            if let captured = move.capturedPiece {
                let captureRow = move.from.row
                setPiece(captured, at: Position(row: captureRow, col: move.to.col))
                if !capturedPieces.isEmpty {
                    capturedPieces.removeLast()
                }
            }
        } else if move.isCastling {
            setPiece(nil, at: move.to)
            let row = move.from.row
            if move.to.col > move.from.col {
                if let rook = piece(at: Position(row: row, col: 5)) {
                    setPiece(nil, at: Position(row: row, col: 5))
                    setPiece(rook, at: Position(row: row, col: 7))
                }
            } else {
                if let rook = piece(at: Position(row: row, col: 3)) {
                    setPiece(nil, at: Position(row: row, col: 3))
                    setPiece(rook, at: Position(row: row, col: 0))
                }
            }
        } else {
            setPiece(move.capturedPiece, at: move.to)
            if move.capturedPiece != nil && !capturedPieces.isEmpty {
                capturedPieces.removeLast()
            }
        }

        lastMove = moveHistoryDetailed.last

        if move.piece.color == .black {
            fullMoveNumber = max(1, fullMoveNumber - 1)
        }
    }

    // MARK: - Draw Rules

    func isFiftyMoveRule() -> Bool {
        return halfMoveClock >= 100
    }

    func isThreefoldRepetition() -> Bool {
        let currentHash = getBoardHash()
        // The last entry in moveHistoryDetailed already stores the current position hash,
        // so we count occurrences from moveHistoryDetailed (which includes the current position)
        // plus the initial position (which is NOT stored in moveHistoryDetailed).
        var repetitionCount = 0

        // Count occurrences in move history (each move stores the position hash AFTER the move)
        for move in moveHistoryDetailed.reversed() {
            if move.positionHash == currentHash {
                repetitionCount += 1
            }
            // Optimization: after a capture or pawn move, the position cannot match
            // any earlier position (pieces changed irreversibly), so we can stop searching
            if move.capturedPiece != nil || move.piece.type == .pawn {
                break
            }
        }

        // Also count the initial position (before any move was played)
        // which is not stored in moveHistoryDetailed
        if initialPositionHash == currentHash {
            repetitionCount += 1
        }

        return repetitionCount >= 3
    }

    /// Expose board hash for testing purposes (internal access)
    func getBoardHashForTest() -> String {
        return getBoardHash()
    }

    private func getBoardHash() -> String {
        var hash = ""
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = board[row][col] {
                    hash += "\(piece.type.rawValue)\(piece.color == .white ? "w" : "b")\(row)\(col)"
                } else {
                    hash += "."
                }
            }
        }
        hash += currentPlayer == .white ? "W" : "B"
        hash += isWhiteKingMoved ? "0" : "1"
        hash += isWhiteRookLeftMoved ? "0" : "1"
        hash += isWhiteRookRightMoved ? "0" : "1"
        hash += isBlackKingMoved ? "0" : "1"
        hash += isBlackRookLeftMoved ? "0" : "1"
        hash += isBlackRookRightMoved ? "0" : "1"

        // FIDE rule: en passant square only counts if an opponent pawn can actually
        // en passant capture. Without this check, two identical positions could get
        // different hashes just because a pawn advanced 2 squares with no adjacent
        // enemy pawn to capture it.
        if let ep = enPassantTarget, canEnPassantBeCaptured(at: ep) {
            hash += "ep\(ep.row)\(ep.col)"
        }

        return hash
    }

    /// Check if there is an opponent pawn that can actually capture en passant at the given square.
    /// The en passant target is the square "behind" the pawn that just advanced 2 squares.
    /// An opponent pawn must be on the same rank as the pawn that advanced, on an adjacent column.
    private func canEnPassantBeCaptured(at epSquare: Position) -> Bool {
        // The pawn that advanced is one rank ahead/behind the ep square
        // depending on whose turn it is (currentPlayer is the one who would capture)
        let capturingColor = currentPlayer
        // The capturing pawn must be on the rank adjacent to the ep square,
        // on the opposite side from where the pawn landed
        let pawnRow: Int
        if capturingColor == .white {
            // White captures upward: white pawn is on row epSquare.row + 1
            pawnRow = epSquare.row + 1
        } else {
            // Black captures downward: black pawn is on row epSquare.row - 1
            pawnRow = epSquare.row - 1
        }

        // Check adjacent columns for a friendly pawn that could capture
        for colOffset in [-1, 1] {
            let col = epSquare.col + colOffset
            guard col >= 0 && col < 8 && pawnRow >= 0 && pawnRow < 8 else { continue }
            if let piece = board[pawnRow][col],
               piece.type == .pawn,
               piece.color == capturingColor {
                return true
            }
        }
        return false
    }
}
