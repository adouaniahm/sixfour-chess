import Foundation

actor ChessAI {
    private let maxDepth: Int
    private let color: PieceColor
    
    private static let infinityValue = 1_000_000_000
    private static let negativeInfinity = -1_000_000_000
    
    // Cache for evaluations (simplified transposition table).
    private var evaluationCache: [String: Int] = [:]

    // Piece-square tables (simplified for performance).
    private static let pawnTable: [[Int]] = [
        [0,  0,  0,  0,  0,  0,  0,  0],
        [50, 50, 50, 50, 50, 50, 50, 50],
        [10, 10, 20, 30, 30, 20, 10, 10],
        [5,  5, 10, 25, 25, 10,  5,  5],
        [0,  0,  0, 20, 20,  0,  0,  0],
        [5, -5,-10,  0,  0,-10, -5,  5],
        [5, 10, 10,-20,-20, 10, 10,  5],
        [0,  0,  0,  0,  0,  0,  0,  0]
    ]

    private static let knightTable: [[Int]] = [
        [-50,-40,-30,-30,-30,-30,-40,-50],
        [-40,-20,  0,  0,  0,  0,-20,-40],
        [-30,  0, 10, 15, 15, 10,  0,-30],
        [-30,  5, 15, 20, 20, 15,  5,-30],
        [-30,  0, 15, 20, 20, 15,  0,-30],
        [-30,  5, 10, 15, 15, 10,  5,-30],
        [-40,-20,  0,  5,  5,  0,-20,-40],
        [-50,-40,-30,-30,-30,-30,-40,-50]
    ]

    private static let kingMiddleGameTable: [[Int]] = [
        [-30,-40,-40,-50,-50,-40,-40,-30],
        [-30,-40,-40,-50,-50,-40,-40,-30],
        [-30,-40,-40,-50,-50,-40,-40,-30],
        [-30,-40,-40,-50,-50,-40,-40,-30],
        [-20,-30,-30,-40,-40,-30,-30,-20],
        [-10,-20,-20,-20,-20,-20,-20,-10],
        [20, 20,  0,  0,  0,  0, 20, 20],
        [20, 30, 10,  0,  0, 10, 30, 20]
    ]

    init(depth: Int = 3, color: PieceColor) {
        self.maxDepth = depth
        self.color = color
    }

    func findBestMove(for board: ChessBoard) async -> Move? {
        let legalMoves = await board.getAllLegalMoves(for: color)
        guard !legalMoves.isEmpty else { return nil }

        var bestMoveSoFar: Move? = legalMoves.first // Initialize with first legal move

        // Iterative Deepening loop
        // The transposition table (evaluationCache) will be automatically reused between iterations
        for currentDepth in 1...maxDepth {
            var bestMoveInIteration: Move?
            var bestScoreForIteration = Self.negativeInfinity
            
            // Order moves, prioritizing the best move found in the previous (shallower) iteration
            let orderedMoves = await orderMoves(legalMoves, on: board, with: bestMoveSoFar)

            for move in orderedMoves {
                let boardCopy = await board.copy()
                await boardCopy.makeMove(move)

                let score = await -negamax(
                    board: boardCopy,
                    depth: currentDepth - 1, // Search to the current iteration's depth
                    alpha: Self.negativeInfinity,
                    beta: Self.infinityValue,
                    color: color.opposite
                )

                if score > bestScoreForIteration {
                    bestScoreForIteration = score
                    bestMoveInIteration = move
                }
            }
            
            // If a move was found for this depth, update the overall best move
            if let move = bestMoveInIteration {
                bestMoveSoFar = move
            }
            
            // Optional: Add time management here. If time is up, break and return bestMoveSoFar.
        }

        return bestMoveSoFar
    }

    private func negamax(
        board: ChessBoard,
        depth: Int,
        alpha: Int,
        beta: Int,
        color: PieceColor
    ) async -> Int {
        // Stop condition.
        if depth == 0 {
            return await evaluateBoard(board, for: color)
        }

        let fenKey = await board.toFEN()
        if let cachedScore = evaluationCache[fenKey] {
            return cachedScore
        }

        // Checkmate / stalemate.
        if await board.isCheckmate(for: color) {
            return -100000 + (maxDepth - depth)
        }

        if await board.isStalemate(for: color) {
            return 0
        }

        let legalMoves = await board.getAllLegalMoves(for: color)
        guard !legalMoves.isEmpty else {
            return await evaluateBoard(board, for: color)
        }

        var alpha = alpha
        var maxScore = Self.negativeInfinity

        // Order moves, which is crucial for alpha-beta pruning.
        let orderedMoves = await orderMoves(legalMoves, on: board)
        
        // Limit the number of deeply searched moves.
        let movesToAnalyze = depth > 2 ? Array(orderedMoves.prefix(20)) : orderedMoves

        for move in movesToAnalyze {
            let boardCopy = await board.copy()
            await boardCopy.makeMove(move)

            let score = await -negamax(
                board: boardCopy,
                depth: depth - 1,
                alpha: -beta,
                beta: -alpha,
                color: color.opposite
            )

            maxScore = max(maxScore, score)
            alpha = max(alpha, score)

            if alpha >= beta {
                break // Alpha-beta cutoff.
            }
        }
        
        evaluationCache[fenKey] = maxScore
        return maxScore
    }

    private func evaluateBoard(_ board: ChessBoard, for color: PieceColor) async -> Int {
        var score = 0

        // Material evaluation.
        for row in 0..<8 {
            for col in 0..<8 {
                let pos = Position(row: row, col: col)
                if let piece = await board.piece(at: pos) {
                    let pieceValue = await evaluatePiece(piece, at: pos)
                    score += piece.color == color ? pieceValue : -pieceValue
                }
            }
        }

        // Mobility bonus, simplified to count only active pieces.
        let centerControl = await evaluateCenterControl(board, for: color)
        score += centerControl * 5

        return score
    }

    private func evaluatePiece(_ piece: Piece, at position: Position) async -> Int {
        var score = piece.value

        let row = piece.color == .white ? position.row : 7 - position.row
        let col = position.col

        switch piece.type {
        case .pawn:
            score += Self.pawnTable[row][col]
        case .knight:
            score += Self.knightTable[row][col]
        case .king:
            score += Self.kingMiddleGameTable[row][col]
        default:
            break // No bonus for the other pieces, by design.
        }

        return score
    }

    private func evaluateCenterControl(_ board: ChessBoard, for color: PieceColor) async -> Int {
        var control = 0
        let centerSquares = [
            Position(row: 3, col: 3), Position(row: 3, col: 4),
            Position(row: 4, col: 3), Position(row: 4, col: 4)
        ]
        
        for pos in centerSquares {
            if let piece = await board.piece(at: pos), piece.color == color {
                control += 1
            }
        }
        
        return control
    }

    private func orderMoves(_ moves: [Move], on board: ChessBoard, with priorityMove: Move? = nil) async -> [Move] {
        
        // 1. Compute all scores.
        var scoredMoves: [(move: Move, score: Int)] = []
        scoredMoves.reserveCapacity(moves.count)

        for move in moves {
            let s = await scoreMoveForOrdering(move)
            scoredMoves.append((move, s))
        }

        // 2. Sort synchronously by score, descending.
        var sortedMoves = scoredMoves.sorted { $0.score > $1.score }.map { $0.move }
        
        // 3. If there is a priority move (for example from a shallower ID search), move it to the front.
        // This is crucial for efficient alpha-beta pruning in iterative deepening.
        if let priority = priorityMove, let index = sortedMoves.firstIndex(of: priority) {
            let element = sortedMoves.remove(at: index)
            sortedMoves.insert(element, at: 0)
        }
        
        return sortedMoves
    }

    private func scoreMoveForOrdering(_ move: Move) async -> Int {
        var score = 0

        // MVV-LVA (Most Valuable Victim - Least Valuable Attacker).
        if let captured = move.capturedPiece {
            score += captured.value * 10 - move.piece.value
        }

        // Promotions.
        if move.promotionType == .queen {
            score += 900
        }

        // Moves toward the center.
        let centerDistance = abs(move.to.row - 4) + abs(move.to.col - 4)
        score += (8 - centerDistance) * 10

        return score
    }
}
