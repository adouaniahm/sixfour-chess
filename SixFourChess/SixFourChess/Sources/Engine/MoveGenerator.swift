import Foundation

/// Generates legal moves for a piece.
nonisolated enum MoveGenerator {

    // MARK: - ChessState Support (Primary)

    static func generateLegalMoves(
        for piece: Piece,
        at position: Position,
        on state: ChessState
    ) -> [Move] {
        let pseudoLegalMoves = generatePseudoLegalMoves(for: piece, at: position, on: state)
        var legalMoves: [Move] = []

        // Struct copy is cheap and safe
        var testState = state

        for move in pseudoLegalMoves {
            testState.makeMove(move)
            if !testState.isInCheck(color: piece.color) {
                legalMoves.append(move)
            }
            testState.undoLastMove()
        }
        return legalMoves
    }

    static func generatePseudoLegalMoves(
        for piece: Piece,
        at position: Position,
        on state: ChessState
    ) -> [Move] {
        switch piece.type {
        case .pawn:
            return generatePawnMoves(for: piece, at: position, on: state)
        case .knight:
            return generateKnightMoves(for: piece, at: position, on: state)
        case .bishop:
            return generateBishopMoves(for: piece, at: position, on: state)
        case .rook:
            return generateRookMoves(for: piece, at: position, on: state)
        case .queen:
            return generateQueenMoves(for: piece, at: position, on: state)
        case .king:
            return generateKingMoves(for: piece, at: position, on: state)
        }
    }

    // MARK: - ChessBoard Convenience

    @MainActor static func generateLegalMoves(
        for piece: Piece,
        at position: Position,
        on board: ChessBoard
    ) -> [Move] {
        return generateLegalMoves(for: piece, at: position, on: board.state)
    }

    @MainActor static func generatePseudoLegalMoves(
        for piece: Piece,
        at position: Position,
        on board: ChessBoard
    ) -> [Move] {
        return generatePseudoLegalMoves(for: piece, at: position, on: board.state)
    }

    // MARK: - Position Attack Check (ChessState)

    private static func isPositionAttacked(
        position: Position,
        by attackerColor: PieceColor,
        on state: ChessState
    ) -> Bool {
        for row in 0..<8 {
            for col in 0..<8 {
                let fromPos = Position(row: row, col: col)
                guard let piece = state.piece(at: fromPos),
                      piece.color == attackerColor else {
                    continue
                }

                if piece.type == .king {
                    let kingOffsets = [
                        (-1, -1), (-1, 0), (-1, 1),
                        (0, -1), (0, 1),
                        (1, -1), (1, 0), (1, 1)
                    ]
                    for (rowOffset, colOffset) in kingOffsets {
                        let attackPos = fromPos.offset(row: rowOffset, col: colOffset)
                        if attackPos == position {
                            return true
                        }
                    }
                } else {
                    let moves = generatePseudoLegalMovesWithoutKing(
                        for: piece,
                        at: fromPos,
                        on: state
                    )
                    if moves.contains(where: { $0.to == position }) {
                        return true
                    }
                }
            }
        }
        return false
    }

    private static func generatePseudoLegalMovesWithoutKing(
        for piece: Piece,
        at position: Position,
        on state: ChessState
    ) -> [Move] {
        switch piece.type {
        case .pawn:
            return generatePawnMoves(for: piece, at: position, on: state)
        case .knight:
            return generateKnightMoves(for: piece, at: position, on: state)
        case .bishop:
            return generateBishopMoves(for: piece, at: position, on: state)
        case .rook:
            return generateRookMoves(for: piece, at: position, on: state)
        case .queen:
            return generateQueenMoves(for: piece, at: position, on: state)
        case .king:
            return []
        }
    }

    // MARK: - Move Logic (ChessState)

    private static func generatePawnMoves(
        for piece: Piece,
        at position: Position,
        on state: ChessState
    ) -> [Move] {
        var moves: [Move] = []
        let direction = piece.color == .white ? -1 : 1
        let startRow = piece.color == .white ? 6 : 1
        let promotionRow = piece.color == .white ? 0 : 7

        let oneForward = position.offset(row: direction, col: 0)
        if oneForward.isValid && state.piece(at: oneForward) == nil {
            if oneForward.row == promotionRow {
                for promotionType in [PieceType.queen, .rook, .bishop, .knight] {
                    moves.append(Move(
                        from: position,
                        to: oneForward,
                        piece: piece,
                        promotionType: promotionType
                    ))
                }
            } else {
                moves.append(Move(from: position, to: oneForward, piece: piece))
            }

            if position.row == startRow {
                let twoForward = position.offset(row: direction * 2, col: 0)
                if twoForward.isValid && state.piece(at: twoForward) == nil {
                    moves.append(Move(from: position, to: twoForward, piece: piece))
                }
            }
        }

        for colOffset in [-1, 1] {
            let capturePos = position.offset(row: direction, col: colOffset)
            if capturePos.isValid {
                if let capturedPiece = state.piece(at: capturePos),
                   capturedPiece.color != piece.color {
                    if capturePos.row == promotionRow {
                        for promotionType in [PieceType.queen, .rook, .bishop, .knight] {
                            moves.append(Move(
                                from: position,
                                to: capturePos,
                                piece: piece,
                                capturedPiece: capturedPiece,
                                promotionType: promotionType
                            ))
                        }
                    } else {
                        moves.append(Move(
                            from: position,
                            to: capturePos,
                            piece: piece,
                            capturedPiece: capturedPiece
                        ))
                    }
                }

                if let enPassantTarget = state.enPassantTarget,
                   capturePos == enPassantTarget {
                    let capturedPawnPos = Position(row: position.row, col: capturePos.col)
                    if let capturedPawn = state.piece(at: capturedPawnPos) {
                        moves.append(Move(
                            from: position,
                            to: capturePos,
                            piece: piece,
                            capturedPiece: capturedPawn,
                            isEnPassant: true
                        ))
                    }
                }
            }
        }

        return moves
    }

    private static func generateKnightMoves(
        for piece: Piece,
        at position: Position,
        on state: ChessState
    ) -> [Move] {
        let offsets = [
            (-2, -1), (-2, 1), (-1, -2), (-1, 2),
            (1, -2), (1, 2), (2, -1), (2, 1)
        ]
        return generateMovesWithOffsets(for: piece, at: position, on: state, offsets: offsets, sliding: false)
    }

    private static func generateBishopMoves(
        for piece: Piece,
        at position: Position,
        on state: ChessState
    ) -> [Move] {
        let offsets = [(-1, -1), (-1, 1), (1, -1), (1, 1)]
        return generateMovesWithOffsets(for: piece, at: position, on: state, offsets: offsets, sliding: true)
    }

    private static func generateRookMoves(
        for piece: Piece,
        at position: Position,
        on state: ChessState
    ) -> [Move] {
        let offsets = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        return generateMovesWithOffsets(for: piece, at: position, on: state, offsets: offsets, sliding: true)
    }

    private static func generateQueenMoves(
        for piece: Piece,
        at position: Position,
        on state: ChessState
    ) -> [Move] {
        let offsets = [
            (-1, -1), (-1, 0), (-1, 1),
            (0, -1), (0, 1),
            (1, -1), (1, 0), (1, 1)
        ]
        return generateMovesWithOffsets(for: piece, at: position, on: state, offsets: offsets, sliding: true)
    }

    private static func generateKingMoves(
        for piece: Piece,
        at position: Position,
        on state: ChessState
    ) -> [Move] {
        var moves: [Move] = []

        let offsets = [
            (-1, -1), (-1, 0), (-1, 1),
            (0, -1), (0, 1),
            (1, -1), (1, 0), (1, 1)
        ]

        moves.append(contentsOf: generateMovesWithOffsets(
            for: piece,
            at: position,
            on: state,
            offsets: offsets,
            sliding: false
        ))

        if !piece.hasMoved {
            let row = position.row
            let kingMoved = piece.color == .white ? state.isWhiteKingMoved : state.isBlackKingMoved

            if !kingMoved {
                let rightRookMoved = piece.color == .white ? state.isWhiteRookRightMoved : state.isBlackRookRightMoved

                if !rightRookMoved {
                    let pos5 = Position(row: row, col: 5)
                    let pos6 = Position(row: row, col: 6)

                    if state.piece(at: pos5) == nil &&
                       state.piece(at: pos6) == nil &&
                       state.piece(at: Position(row: row, col: 7))?.type == .rook {
                        
                        let kingIsAttacked = isPositionAttacked(position: position, by: piece.color.opposite, on: state)
                        let pos5IsAttacked = isPositionAttacked(position: pos5, by: piece.color.opposite, on: state)
                        let pos6IsAttacked = isPositionAttacked(position: pos6, by: piece.color.opposite, on: state)
                        
                        if !kingIsAttacked && !pos5IsAttacked && !pos6IsAttacked {
                            moves.append(Move(
                                from: position,
                                to: pos6,
                                piece: piece,
                                isCastling: true
                            ))
                        }
                    }
                }

                let leftRookMoved = piece.color == .white ? state.isWhiteRookLeftMoved : state.isBlackRookLeftMoved

                if !leftRookMoved {
                    let pos1 = Position(row: row, col: 1)
                    let pos2 = Position(row: row, col: 2)
                    let pos3 = Position(row: row, col: 3)

                    if state.piece(at: pos1) == nil &&
                       state.piece(at: pos2) == nil &&
                       state.piece(at: pos3) == nil &&
                       state.piece(at: Position(row: row, col: 0))?.type == .rook {
                        
                        let kingIsAttacked = isPositionAttacked(position: position, by: piece.color.opposite, on: state)
                        let pos3IsAttacked = isPositionAttacked(position: pos3, by: piece.color.opposite, on: state)
                        let pos2IsAttacked = isPositionAttacked(position: pos2, by: piece.color.opposite, on: state)
                        
                        if !kingIsAttacked && !pos3IsAttacked && !pos2IsAttacked {
                            moves.append(Move(
                                from: position,
                                to: pos2,
                                piece: piece,
                                isCastling: true
                            ))
                        }
                    }
                }
            }
        }

        return moves
    }

    private static func generateMovesWithOffsets(
        for piece: Piece,
        at position: Position,
        on state: ChessState,
        offsets: [(Int, Int)],
        sliding: Bool
    ) -> [Move] {
        var moves: [Move] = []

        for (rowOffset, colOffset) in offsets {
            var currentPos = position.offset(row: rowOffset, col: colOffset)

            while currentPos.isValid {
                if let targetPiece = state.piece(at: currentPos) {
                    if targetPiece.color != piece.color {
                        moves.append(Move(
                            from: position,
                            to: currentPos,
                            piece: piece,
                            capturedPiece: targetPiece
                        ))
                    }
                    break
                } else {
                    moves.append(Move(from: position, to: currentPos, piece: piece))
                }

                if !sliding {
                    break
                }

                currentPos = currentPos.offset(row: rowOffset, col: colOffset)
            }
        }

        return moves
    }
}
