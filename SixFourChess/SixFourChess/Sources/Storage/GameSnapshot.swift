import Foundation

// MARK: - Snapshot Models

struct ChessBoardSnapshot: Codable {
    let board: [[Piece?]]
    let currentPlayer: PieceColor
    let moveHistory: [String]  // Algebraic notation.
    let moveHistoryDetailed: [Move]  // For undo.
    let capturedPieces: [Piece]
    let lastMove: Move?
    let enPassantTarget: Position?
    let isWhiteKingMoved: Bool
    let isBlackKingMoved: Bool
    let isWhiteRookLeftMoved: Bool
    let isWhiteRookRightMoved: Bool
    let isBlackRookLeftMoved: Bool
    let isBlackRookRightMoved: Bool
    let halfMoveClock: Int
    let fullMoveNumber: Int
}

struct GameStateSnapshot: Codable {
    let board: ChessBoardSnapshot
    let mode: GameModeState  // Save the full GameModeState instead of the legacy GameMode.
    let isActive: Bool
    let gameResult: GameResult?
    let suggestedMove: Move?
    let startedAt: Date
    let isArchivedInHistory: Bool
    let hintsRemaining: Int
    let savedAt: Date

    // Legacy fields kept for backward compatibility with old saves.
    let gameMode: GameMode?
    let difficulty: AIDifficulty?
    let whiteAIEnabled: Bool?
    let blackAIEnabled: Bool?

    private enum CodingKeys: String, CodingKey {
        case board
        case mode
        case isActive
        case gameResult
        case suggestedMove
        case startedAt
        case isArchivedInHistory
        case hintsRemaining
        case savedAt
        case gameMode
        case difficulty
        case whiteAIEnabled
        case blackAIEnabled
    }

    init(
        board: ChessBoardSnapshot,
        mode: GameModeState,
        isActive: Bool,
        gameResult: GameResult?,
        suggestedMove: Move?,
        startedAt: Date,
        isArchivedInHistory: Bool,
        hintsRemaining: Int,
        savedAt: Date,
        gameMode: GameMode?,
        difficulty: AIDifficulty?,
        whiteAIEnabled: Bool?,
        blackAIEnabled: Bool?
    ) {
        self.board = board
        self.mode = mode
        self.isActive = isActive
        self.gameResult = gameResult
        self.suggestedMove = suggestedMove
        self.startedAt = startedAt
        self.isArchivedInHistory = isArchivedInHistory
        self.hintsRemaining = hintsRemaining
        self.savedAt = savedAt
        self.gameMode = gameMode
        self.difficulty = difficulty
        self.whiteAIEnabled = whiteAIEnabled
        self.blackAIEnabled = blackAIEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        board = try container.decode(ChessBoardSnapshot.self, forKey: .board)
        mode = try container.decode(GameModeState.self, forKey: .mode)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        gameResult = try container.decodeIfPresent(GameResult.self, forKey: .gameResult)
        suggestedMove = try container.decodeIfPresent(Move.self, forKey: .suggestedMove)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? savedAt
        isArchivedInHistory = try container.decodeIfPresent(Bool.self, forKey: .isArchivedInHistory) ?? false
        hintsRemaining = try container.decodeIfPresent(Int.self, forKey: .hintsRemaining) ?? 3
        gameMode = try container.decodeIfPresent(GameMode.self, forKey: .gameMode)
        difficulty = try container.decodeIfPresent(AIDifficulty.self, forKey: .difficulty)
        whiteAIEnabled = try container.decodeIfPresent(Bool.self, forKey: .whiteAIEnabled)
        blackAIEnabled = try container.decodeIfPresent(Bool.self, forKey: .blackAIEnabled)
    }
}

// MARK: - ChessBoard Snapshot Support

extension ChessBoard {
    var snapshot: ChessBoardSnapshot {
        ChessBoardSnapshot(
            board: board,
            currentPlayer: currentPlayer,
            moveHistory: moveHistory,
            moveHistoryDetailed: moveHistoryDetailed,
            capturedPieces: capturedPieces,
            lastMove: lastMove,
            enPassantTarget: enPassantTarget,
            isWhiteKingMoved: isWhiteKingMoved,
            isBlackKingMoved: isBlackKingMoved,
            isWhiteRookLeftMoved: isWhiteRookLeftMoved,
            isWhiteRookRightMoved: isWhiteRookRightMoved,
            isBlackRookLeftMoved: isBlackRookLeftMoved,
            isBlackRookRightMoved: isBlackRookRightMoved,
            halfMoveClock: halfMoveClock,
            fullMoveNumber: fullMoveNumber
        )
    }

    convenience init(snapshot: ChessBoardSnapshot) {
        self.init(
            board: snapshot.board,
            currentPlayer: snapshot.currentPlayer,
            moveHistory: snapshot.moveHistory,
            moveHistoryDetailed: snapshot.moveHistoryDetailed,
            capturedPieces: snapshot.capturedPieces,
            lastMove: snapshot.lastMove,
            enPassantTarget: snapshot.enPassantTarget,
            isWhiteKingMoved: snapshot.isWhiteKingMoved,
            isBlackKingMoved: snapshot.isBlackKingMoved,
            isWhiteRookLeftMoved: snapshot.isWhiteRookLeftMoved,
            isWhiteRookRightMoved: snapshot.isWhiteRookRightMoved,
            isBlackRookLeftMoved: snapshot.isBlackRookLeftMoved,
            isBlackRookRightMoved: snapshot.isBlackRookRightMoved,
            halfMoveClock: snapshot.halfMoveClock,
            fullMoveNumber: snapshot.fullMoveNumber
        )
    }
}

// MARK: - GameState Snapshot Support

extension GameState {
    func snapshot() -> GameStateSnapshot {
        GameStateSnapshot(
            board: board.snapshot,
            mode: mode,  // 🆕 Save full GameModeState
            isActive: isActive,
            gameResult: gameResult,
            suggestedMove: suggestedMove,
            startedAt: startedAt,
            isArchivedInHistory: isArchivedInHistory,
            hintsRemaining: hintsRemaining,
            savedAt: Date(),
            // Legacy fields set to nil (for backward compatibility)
            gameMode: nil,
            difficulty: nil,
            whiteAIEnabled: nil,
            blackAIEnabled: nil
        )
    }

    mutating func applySnapshot(_ snapshot: GameStateSnapshot) {
        // Fix: Update state instead of replacing instance to preserve SwiftUI observation
        let newBoard = ChessBoard(snapshot: snapshot.board)
        board.state = newBoard.state

        // Use new mode if available, otherwise convert from legacy fields
        if let legacyMode = snapshot.gameMode {
            // Legacy snapshot: convert to new GameModeState
            let legacyDifficulty = snapshot.difficulty ?? .medium
            mode = GameModeState.from(legacyMode: legacyMode, difficulty: legacyDifficulty)
        } else {
            // New snapshot: use GameModeState directly
            mode = snapshot.mode
        }

        isActive = snapshot.isActive
        gameResult = snapshot.gameResult
        suggestedMove = snapshot.suggestedMove
        startedAt = snapshot.startedAt
        isArchivedInHistory = snapshot.isArchivedInHistory
        hintsRemaining = snapshot.hintsRemaining

        // Reset UI-specific state
        isThinking = false
        isCalculatingHint = false
        selectedPosition = nil
        availableMoves = []
    }
}

struct PlayedGameRecord: Codable, Identifiable {
    let id: String
    let startedAt: Date
    let finishedAt: Date
    let result: GameResult?
    let moveHistory: [String]
    let moveHistoryDetailed: [Move]
    let mode: GameModeState
    let difficulty: AIDifficulty

    var moveCount: Int { moveHistory.count }
    var resultText: String { result?.description ?? "history.result.abandoned".localized }

    private enum CodingKeys: String, CodingKey {
        case id
        case startedAt
        case finishedAt
        case result
        case moveHistory
        case moveHistoryDetailed
        case mode
        case difficulty
    }

    init(
        id: String,
        startedAt: Date,
        finishedAt: Date,
        result: GameResult?,
        moveHistory: [String],
        moveHistoryDetailed: [Move],
        mode: GameModeState,
        difficulty: AIDifficulty
    ) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.result = result
        self.moveHistory = moveHistory
        self.moveHistoryDetailed = moveHistoryDetailed
        self.mode = mode
        self.difficulty = difficulty
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        finishedAt = try container.decode(Date.self, forKey: .finishedAt)
        result = try container.decodeIfPresent(GameResult.self, forKey: .result)
        moveHistory = try container.decode([String].self, forKey: .moveHistory)
        moveHistoryDetailed = try container.decodeIfPresent([Move].self, forKey: .moveHistoryDetailed) ?? []
        mode = try container.decodeIfPresent(GameModeState.self, forKey: .mode) ?? .ai(AIConfig(whiteEnabled: false, blackEnabled: true, difficulty: .medium))
        difficulty = try container.decodeIfPresent(AIDifficulty.self, forKey: .difficulty) ?? .medium
    }
}
