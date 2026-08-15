//
//  AIReduxMiddleware.swift
//  SixFourChess
//
//  AI Middleware using ReduxMiddleware pattern
//
//  ROUTING IA :
//    Manages two AI pipelines in parallel:
//    1. RAGChessAI (principal) : Negamax + Opening Book + NNUE + RAG bias
//    2. ChessAI (fallback)     : Negamax + classic heuristic evaluation
//
//    If RAGChessAI is available, it is used first.
//    If the embedded model is unavailable, ChessAI takes over.
//
//  INFRASTRUCTURE RAG :
//    Initialized lazily on the first `.triggerAIMove`.
//    Composed of BoardEncoder + OpeningBook + NNUEEvaluator + PositionVectorStore.
//    Each component is optional — RAGChessAI still works in degraded mode.

import Foundation

// MARK: - RAGInfrastructure
//
// Conteneur des composants partagés entre les instances RAGChessAI.
// Initialisé une seule fois et partagé entre whiteRAGAI et blackRAGAI.
// Les composants sont optionnels : l'IA fonctionne même sans modèle NNUE.

/// Composants RAG partagés entre les instances IA.
///
/// Créé au premier match vs IA et réutilisé ensuite.
/// Chaque composant est nil-safe — RAGChessAI les ignore s'ils sont absents.
struct RAGInfrastructure: @unchecked Sendable {
    /// Encodeur Zobrist + feature vector (toujours disponible)
    let encoder: BoardEncoder
    /// Opening book Polyglot (nil si fichier .bin non bundlé)
    let openingBook: OpeningBook?
    /// Évaluateur NNUE CoreML (nil si le modèle embarqué est indisponible)
    let nnueEvaluator: NNUEEvaluator?
    /// Base vectorielle SQLite (réservée à une future source de données vérifiée)
    let vectorStore: PositionVectorStore?
}

// MARK: - AIReduxMiddleware
//
// ROLE : Gère les instances ChessAI/RAGChessAI et le calcul des coups IA + hints.
//        Creates or destroys AI instances according to the game mode and difficulty.
//        Initialise l'infrastructure RAG (encoder, book, NNUE, vectorStore) en lazy.
//
// ACTIONS INTERCEPTEES :
//   .game(.newGame)           -> creates AI instances according to the config (white/black)
//   .game(.triggerAIMove)     -> lance le calcul du prochain coup IA (async)
//   .game(.requestHint)       -> lance le calcul d'un conseil pour le joueur (async)
//   .game(.changeDifficulty)  -> recreates AI instances with the new difficulty
//
// EFFETS DE BORD :
//   - CPU-intensive computation: Negamax alpha-beta + NNUE/heuristic evaluation
//   - Creates/destroys ChessAI and RAGChessAI instances via AIMutationManager
//   - Loads AI assets (opening book, NNUE model, position database)
//
// ACTIONS DISPATCHEES :
//   .game(.setAIThinking(true/false))  -> indicateur de chargement
//   .game(.aiMoveCalculated(move))     -> AI-calculated move
//   .game(.setHint(move))              -> calculated hint
//   .game(.setCalculatingHint)         -> indicateur de calcul hint

/// Gestionnaire thread-safe des instances IA (blanc et/ou noir).
///
/// Maintient les instances legacy (ChessAI), RAG (RAGChessAI), et cloud (StockfishCloudAI).
/// Priorité : Cloud > RAG > Legacy.
@MainActor
final class AIMutationManager {
    // Legacy AI (toujours créée, sert de fallback)
    var whiteAI: ChessAI?
    var blackAI: ChessAI?

    // RAG AI (créée si l'infrastructure RAG est disponible)
    var whiteRAGAI: RAGChessAI?
    var blackRAGAI: RAGChessAI?

    // Cloud AI (uniquement pour .master — Stockfish cloud)
    var whiteCloudAI: StockfishCloudAI?
    var blackCloudAI: StockfishCloudAI?

    /// Infrastructure RAG partagée entre les instances.
    /// Initialisée en lazy au premier match vs IA.
    var ragInfrastructure: RAGInfrastructure?

    /// true si l'initialisation RAG est en cours (évite les doubles appels)
    var isInitializingRAG = false
}

@MainActor
final class AIReduxMiddleware: ReduxMiddleware {
    private let aiManager = AIMutationManager()
    private let dispatchContext: DispatchContext

    nonisolated init(dispatchContext: DispatchContext) {
        self.dispatchContext = dispatchContext
    }

    func invoke(action: ReduxAction, state: AppState) -> ReduxFlow<Mutation> {
        guard let appAction = action as? AppAction,
              case .game(let gameAction) = appAction else {
            return emptyFlow()
        }

        let gameState = state.gameState

        // Lazy init de l'infrastructure RAG au premier besoin
        // (ne bloque pas — s'exécute en background)
        initializeRAGInfrastructureIfNeeded()

        // Initialize legacy AI if needed (toujours créée comme fallback)
        if aiManager.whiteAI == nil && gameState.whiteAIEnabled {
            aiManager.whiteAI = ChessAI(depth: gameState.difficulty.depth, color: .white)
        }
        if aiManager.blackAI == nil && gameState.blackAIEnabled {
            aiManager.blackAI = ChessAI(depth: gameState.difficulty.depth, color: .black)
        }

        switch gameAction {
        case .newGame(let mode, let difficulty):
            // Recréer les instances IA (legacy + RAG + cloud) avec la nouvelle difficulté
            if mode == .playerVsAI {
                // Legacy AI : noir uniquement (l'humain joue les blancs)
                aiManager.whiteAI = nil
                aiManager.blackAI = ChessAI(depth: difficulty.depth, color: .black)

                // Cloud AI : uniquement pour .master
                aiManager.whiteCloudAI = nil
                if difficulty == .master {
                    aiManager.blackCloudAI = StockfishCloudAI(color: .black)
                    Logger.info("New game vs Stockfish Cloud AI - Master difficulty", subsystem: .game)
                } else {
                    aiManager.blackCloudAI = nil
                }

                // RAG AI : créer si infrastructure disponible (sert aussi de fallback pour .master)
                aiManager.whiteRAGAI = nil
                if let infra = aiManager.ragInfrastructure {
                    aiManager.blackRAGAI = RAGChessAI(
                        difficulty: difficulty,
                        color: .black,
                        encoder: infra.encoder,
                        openingBook: infra.openingBook,
                        nnueEvaluator: infra.nnueEvaluator,
                        vectorStore: infra.vectorStore
                    )
                    if difficulty != .master {
                        Logger.info("New game vs RAG AI - difficulty: \(difficulty)", subsystem: .game)
                    }
                } else {
                    aiManager.blackRAGAI = nil
                    if difficulty != .master {
                        Logger.info("New game vs legacy AI - difficulty: \(difficulty) (RAG not ready)", subsystem: .game)
                    }
                }
            } else {
                aiManager.whiteAI = nil
                aiManager.blackAI = nil
                aiManager.whiteRAGAI = nil
                aiManager.blackRAGAI = nil
                aiManager.whiteCloudAI = nil
                aiManager.blackCloudAI = nil
                Logger.info("New game - mode: \(mode)", subsystem: .game)
            }
            return emptyFlow()

        case .triggerAIMove:
            Logger.debug("AI move triggered for \(gameState.board.currentPlayer)", subsystem: .game)
            calculateAIMove(gameState: gameState)
            return emptyFlow()

        case .retryCloudAI:
            Logger.info("Retrying Stockfish Cloud AI", subsystem: .game)
            dispatchContext.dispatch(AppAction.ui(.setCloudError(show: false, isNetwork: false)))
            calculateAIMove(gameState: gameState)
            return emptyFlow()

        case .requestHint:
            Logger.info("Hint requested", subsystem: .game)
            guard gameState.hintsRemaining > 0 else {
                dispatchContext.dispatch(AppAction.ui(.setErrorAlert(
                    title: "help.limit.title".localized,
                    message: "help.limit.message".localized
                )))
                return emptyFlow()
            }
            calculateHint(gameState: gameState)
            return emptyFlow()

        case .changeDifficulty(let difficulty):
            Logger.info("Difficulty changed to \(difficulty)", subsystem: .game)
            // Masquer l'overlay cloud si on change de difficulté
            dispatchContext.dispatch(AppAction.ui(.setCloudError(show: false, isNetwork: false)))

            // Recréer les instances legacy
            if gameState.whiteAIEnabled {
                aiManager.whiteAI = ChessAI(depth: difficulty.depth, color: .white)
            }
            if gameState.blackAIEnabled {
                aiManager.blackAI = ChessAI(depth: difficulty.depth, color: .black)
            }

            // Cloud AI : uniquement pour .master
            if difficulty == .master {
                if gameState.whiteAIEnabled {
                    aiManager.whiteCloudAI = StockfishCloudAI(color: .white)
                }
                if gameState.blackAIEnabled {
                    aiManager.blackCloudAI = StockfishCloudAI(color: .black)
                }
            } else {
                aiManager.whiteCloudAI = nil
                aiManager.blackCloudAI = nil
            }

            // Recréer les instances RAG si infrastructure disponible
            if let infra = aiManager.ragInfrastructure {
                if gameState.whiteAIEnabled {
                    aiManager.whiteRAGAI = RAGChessAI(
                        difficulty: difficulty,
                        color: .white,
                        encoder: infra.encoder,
                        openingBook: infra.openingBook,
                        nnueEvaluator: infra.nnueEvaluator,
                        vectorStore: infra.vectorStore
                    )
                }
                if gameState.blackAIEnabled {
                    aiManager.blackRAGAI = RAGChessAI(
                        difficulty: difficulty,
                        color: .black,
                        encoder: infra.encoder,
                        openingBook: infra.openingBook,
                        nnueEvaluator: infra.nnueEvaluator,
                        vectorStore: infra.vectorStore
                    )
                }
            }
            return emptyFlow()

        default:
            return emptyFlow()
        }
    }

    // MARK: - RAG Infrastructure Initialization

    /// Lazily initializes the RAG infrastructure on first use.
    ///
    /// Creates the shared components: encoder, opening book, NNUE, and vector store.
    /// Non-blocking: runs inside a background Task.
    /// Idempotent: does nothing if initialization already happened or is in progress.
    private func initializeRAGInfrastructureIfNeeded() {
        // Already ready or already initializing — nothing to do.
        guard aiManager.ragInfrastructure == nil,
              !aiManager.isInitializingRAG else { return }

        aiManager.isInitializingRAG = true
        Logger.info("Initializing RAG infrastructure...", subsystem: .game)

        Task {
            let encoder = BoardEncoder()

            // 1. Opening book: look it up in the bundle.
            var openingBook: OpeningBook?
            if let bookURL = Bundle.main.url(forResource: "opening_book", withExtension: "bin") {
                do {
                    openingBook = try OpeningBook(url: bookURL)
                    Logger.success("Opening book loaded", subsystem: .game)
                } catch {
                    Logger.warning("Opening book load failed: \(error.localizedDescription)", subsystem: .game)
                }
            } else {
                Logger.info("No opening book bundled — skipping", subsystem: .game)
            }

            // 2. NNUE: always create the evaluator, since it is a shared reference type.
            //    The model is bundled in `Resources/nnue.mlmodelc`.
            //    `RAGChessAI.evaluate(...)` handles the `model == nil` case with a heuristic fallback.
            var nnueEvaluator: NNUEEvaluator?
            if #available(iOS 17.0, *) {
                let evaluator = NNUEEvaluator(encoder: encoder)
                nnueEvaluator = evaluator

                // Look for the bundled model in the app bundle.
                if let bundledURL = Bundle.main.url(forResource: "nnue", withExtension: "mlmodelc") {
                    do {
                        try await evaluator.loadModel(from: bundledURL)
                        Logger.success("NNUE model loaded from bundle ✓", subsystem: .game)
                    } catch {
                        Logger.warning("Bundled NNUE model load failed: \(error.localizedDescription)", subsystem: .game)
                    }
                } else {
                    Logger.warning("Bundled NNUE model not found — using heuristic evaluation", subsystem: .game)
                }
            }

            // 3. The vector store is not distributed in this release.
            let vectorStore: PositionVectorStore? = nil

            // Build the infrastructure object.
            let infra = RAGInfrastructure(
                encoder: encoder,
                openingBook: openingBook,
                nnueEvaluator: nnueEvaluator,
                vectorStore: vectorStore
            )

            // Switch back to the MainActor for state mutation.
            await MainActor.run {
                self.aiManager.ragInfrastructure = infra
                self.aiManager.isInitializingRAG = false
                Logger.success("RAG infrastructure ready (book: \(openingBook != nil), nnue: \(nnueEvaluator != nil), vectorStore: \(vectorStore != nil))", subsystem: .game)
            }
        }
    }

    // MARK: - AI Calculation

    /// Calcule le meilleur coup IA pour le joueur courant.
    ///
    /// Pipeline de sélection :
    /// 0. Si StockfishCloudAI est disponible (.master) → l'utiliser en priorité
    /// 1. Si RAGChessAI est disponible → l'utiliser (ou fallback cloud)
    /// 2. Si RAGChessAI retourne nil → fallback sur ChessAI legacy
    /// 3. Si aucune instance IA → log warning
    private func calculateAIMove(gameState: GameState) {
        let currentPlayer = gameState.board.currentPlayer

        // If the RAG infrastructure is ready but the AI instance does not exist yet
        // (the async init finished after .newGame), create it on demand.
        if let infra = aiManager.ragInfrastructure {
            if currentPlayer == .white && aiManager.whiteRAGAI == nil && gameState.whiteAIEnabled {
                aiManager.whiteRAGAI = RAGChessAI(
                    difficulty: gameState.difficulty,
                    color: .white,
                    encoder: infra.encoder,
                    openingBook: infra.openingBook,
                    nnueEvaluator: infra.nnueEvaluator,
                    vectorStore: infra.vectorStore
                )
                Logger.info("RAG AI created on-demand for white", subsystem: .game)
            }
            if currentPlayer == .black && aiManager.blackRAGAI == nil && gameState.blackAIEnabled {
                aiManager.blackRAGAI = RAGChessAI(
                    difficulty: gameState.difficulty,
                    color: .black,
                    encoder: infra.encoder,
                    openingBook: infra.openingBook,
                    nnueEvaluator: infra.nnueEvaluator,
                    vectorStore: infra.vectorStore
                )
                Logger.info("RAG AI created on-demand for black", subsystem: .game)
            }
        }

        // Create the cloud AI on demand for .master difficulty.
        // Same pattern as above: it guarantees availability after a snapshot restore,
        // a retry, or the first `triggerAIMove` call.
        if gameState.difficulty == .master {
            if currentPlayer == .white && aiManager.whiteCloudAI == nil && gameState.whiteAIEnabled {
                aiManager.whiteCloudAI = StockfishCloudAI(color: .white)
                Logger.info("Cloud AI created on-demand for white", subsystem: .game)
            }
            if currentPlayer == .black && aiManager.blackCloudAI == nil && gameState.blackAIEnabled {
                aiManager.blackCloudAI = StockfishCloudAI(color: .black)
                Logger.info("Cloud AI created on-demand for black", subsystem: .game)
            }
        }

        // AI selection order: Cloud > RAG > Legacy
        let cloudAI: StockfishCloudAI? = currentPlayer == .white
            ? aiManager.whiteCloudAI
            : aiManager.blackCloudAI
        let ragAI: RAGChessAI? = currentPlayer == .white
            ? aiManager.whiteRAGAI
            : aiManager.blackRAGAI
        let legacyAI: ChessAI? = currentPlayer == .white
            ? aiManager.whiteAI
            : aiManager.blackAI

        guard cloudAI != nil || ragAI != nil || legacyAI != nil else {
            Logger.warning("No AI instance for \(currentPlayer)", subsystem: .game)
            return
        }

        Logger.debug("AI thinking started... (Cloud: \(cloudAI != nil), RAG: \(ragAI != nil))", subsystem: .game)
        dispatchContext.dispatch(AppAction.game(.setAIThinking(isThinking: true)))

        Task {
            do {
                // Short delay so the UI can show the thinking indicator.
                try await Task.sleep(nanoseconds: 500_000_000)

                var bestMove: Move?

                // 0. Try Stockfish Cloud first (.master).
                if let cloudAI = cloudAI {
                    let result = await cloudAI.findBestMoveResult(for: gameState.board)
                    switch result {
                    case .success(let move):
                        bestMove = move
                        Logger.debug("Stockfish Cloud AI provided the move", subsystem: .game)
                        // Hide any previous error state.
                        self.dispatchContext.dispatch(AppAction.ui(.setCloudError(show: false, isNetwork: false)))
                    case .networkError:
                        Logger.warning("Stockfish Cloud: network error — showing overlay", subsystem: .game)
                        self.dispatchContext.dispatch(AppAction.game(.setAIThinking(isThinking: false)))
                        self.dispatchContext.dispatch(AppAction.ui(.setCloudError(show: true, isNetwork: true)))
                        return // No fallback: the overlay lets the user decide.
                    case .apiError:
                        Logger.warning("Stockfish Cloud: API error — showing overlay", subsystem: .game)
                        self.dispatchContext.dispatch(AppAction.game(.setAIThinking(isThinking: false)))
                        self.dispatchContext.dispatch(AppAction.ui(.setCloudError(show: true, isNetwork: false)))
                        return // No fallback.
                    }
                }

                // 1. Try RAGChessAI (normal priority, no cloud).
                if bestMove == nil, let ragAI = ragAI {
                    bestMove = await ragAI.findBestMove(for: gameState.board)
                    if bestMove != nil {
                        Logger.debug("RAG AI provided the move", subsystem: .game)
                    }
                }

                // 2. Fallback to the legacy ChessAI.
                if bestMove == nil, let legacyAI = legacyAI {
                    bestMove = await legacyAI.findBestMove(for: gameState.board)
                    if bestMove != nil {
                        Logger.debug("Legacy AI provided the move (RAG fallback)", subsystem: .game)
                    }
                }

                if let bestMove = bestMove {
                    Logger.success("AI found move: \(bestMove.piece.type) \(positionToChessNotation(bestMove.from))->\(positionToChessNotation(bestMove.to))", subsystem: .game)
                    dispatchContext.dispatch(AppAction.game(.setAIThinking(isThinking: false)))

                    // Check whether this is a promotion and show the alert before playing it.
                    if let promotionType = bestMove.promotionType {
                        Logger.info("AI promotes pawn to \(promotionType)", subsystem: .game)
                        dispatchContext.dispatch(AppAction.ui(.setAIPromotionAlert(pieceType: promotionType, move: bestMove)))
                    } else {
                        dispatchContext.dispatch(AppAction.ui(.animateMove(move: bestMove)))
                    }
                } else {
                    Logger.warning("AI found no valid move", subsystem: .game)
                    dispatchContext.dispatch(AppAction.game(.setAIThinking(isThinking: false)))
                }
            } catch {
                Logger.error("AI calculation cancelled", subsystem: .game)
                dispatchContext.dispatch(AppAction.game(.setAIThinking(isThinking: false)))
            }
        }
    }

    /// Calcule un hint (conseil) pour le joueur humain.
    ///
    /// Utilise RAGChessAI si disponible pour un meilleur conseil,
    /// sinon fallback sur ChessAI legacy.
    private func calculateHint(gameState: GameState) {
        dispatchContext.dispatch(AppAction.game(.setCalculatingHint(isCalculating: true)))

        // Create a temporary AI instance for the hint.
        // Cloud (.master) > RAG > Legacy — same pipeline as the main bot.
        let difficulty = gameState.difficulty
        let currentPlayer = gameState.board.currentPlayer

        Task {
            var hintMove: Move?

            // 0. Essayer Stockfish Cloud pour la difficulté .master
            if difficulty == .master {
                let cloudHint = StockfishCloudAI(color: currentPlayer)
                let result = await cloudHint.findBestMoveResult(for: gameState.board)
                switch result {
                case .success(let move):
                    hintMove = move
                    Logger.debug("Hint: Stockfish Cloud provided the move", subsystem: .game)
                case .networkError:
                    Logger.warning("Hint: Stockfish Cloud network error — showing overlay", subsystem: .game)
                    self.dispatchContext.dispatch(AppAction.game(.setCalculatingHint(isCalculating: false)))
                    self.dispatchContext.dispatch(AppAction.ui(.setCloudError(show: true, isNetwork: true)))
                    return
                case .apiError:
                    Logger.warning("Hint: Stockfish Cloud API error — showing overlay", subsystem: .game)
                    self.dispatchContext.dispatch(AppAction.game(.setCalculatingHint(isCalculating: false)))
                    self.dispatchContext.dispatch(AppAction.ui(.setCloudError(show: true, isNetwork: false)))
                    return
                }
            }

            // 1. Essayer avec RAGChessAI si l'infrastructure est prête
            if hintMove == nil, let infra = aiManager.ragInfrastructure {
                let hintRAG = RAGChessAI(
                    difficulty: difficulty,
                    color: currentPlayer,
                    encoder: infra.encoder,
                    openingBook: infra.openingBook,
                    nnueEvaluator: infra.nnueEvaluator,
                    vectorStore: infra.vectorStore
                )
                hintMove = await hintRAG.findBestMove(for: gameState.board)
            }

            // 2. Fallback sur ChessAI legacy
            if hintMove == nil {
                let hintLegacy = ChessAI(depth: difficulty.depth, color: currentPlayer)
                hintMove = await hintLegacy.findBestMove(for: gameState.board)
            }

            if let hintMove = hintMove {
                Logger.success("Hint found: \(hintMove.piece.type) \(positionToChessNotation(hintMove.from))->\(positionToChessNotation(hintMove.to))", subsystem: .game)
                let hintText = formatDetailedHintText(for: hintMove, board: gameState.board)

                dispatchContext.dispatch(AppAction.game(.setHint(move: hintMove)))
                dispatchContext.dispatch(AppAction.game(.setCalculatingHint(isCalculating: false)))
                dispatchContext.dispatch(AppAction.ui(.setHintAlert(hint: hintText)))
            } else {
                Logger.warning("No hint available", subsystem: .game)
                dispatchContext.dispatch(AppAction.game(.setCalculatingHint(isCalculating: false)))
                dispatchContext.dispatch(AppAction.ui(.setHintAlert(hint: "help.noMoves".localized)))
            }
        }
    }

    // MARK: - Hint Formatting

    private func formatDetailedHintText(for move: Move, board: ChessBoard) -> String {
        var hint = ""

        let isInCheck = board.isInCheck(color: board.currentPlayer)
        if isInCheck {
            hint += "help.warning.check".localized + "\n\n"
        }

        hint += "help.suggestedMove".localized
        hint += describeMoveInFrench(move)
        hint += "\n\n"

        let analysis = analyzeMoveReason(move, board: board)
        hint += "help.whyGood".localized + "\n" + analysis

        return hint
    }

    private func describeMoveInFrench(_ move: Move) -> String {
        let pieceNames: [PieceType: String] = [
            .king: "piece.king".localized,
            .queen: "piece.queen".localized,
            .rook: "piece.rook".localized,
            .bishop: "piece.bishop".localized,
            .knight: "piece.knight".localized,
            .pawn: "piece.pawn".localized
        ]

        let pieceName = pieceNames[move.piece.type] ?? "Piece"
        let fromSquare = positionToChessNotation(move.from)
        let toSquare = positionToChessNotation(move.to)

        if move.isCastling {
            return move.to.col > move.from.col ? "move.shortCastle".localized : "move.longCastle".localized
        } else if move.capturedPiece != nil {
            let capturedName = pieceNames[move.capturedPiece!.type] ?? "piece"
            return "\(pieceName) \("move.from".localized) \(fromSquare) \("move.captures".localized) \(capturedName) \("move.to".localized) \(toSquare)"
        } else {
            return "\(pieceName) \("move.from".localized) \(fromSquare) \("move.to".localized) \(toSquare)"
        }
    }

    private func positionToChessNotation(_ position: Position) -> String {
        let files = ["a", "b", "c", "d", "e", "f", "g", "h"]
        let file = files[position.col]
        let rank = 8 - position.row
        return "\(file)\(rank)"
    }

    private func analyzeMoveReason(_ move: Move, board: ChessBoard) -> String {
        var reasons: [String] = []

        if let captured = move.capturedPiece {
            let values: [PieceType: Int] = [.pawn: 1, .knight: 3, .bishop: 3, .rook: 5, .queen: 9, .king: 0]
            let value = values[captured.type] ?? 0
            reasons.append("help.capturesPiece".localized(with: value))
        }

        if move.isCastling {
            reasons.append("help.castles".localized)
            reasons.append("help.activatesRook".localized)
        }

        if move.promotionType != nil {
            reasons.append("help.promotion".localized)
        }

        let toSquare = move.to

        if (toSquare.row >= 3 && toSquare.row <= 4) && (toSquare.col >= 3 && toSquare.col <= 4) {
            reasons.append("help.controlsCenter".localized)
        }

        if move.piece.type != .pawn && move.from.row == (move.piece.color == .white ? 7 : 0) {
            reasons.append("help.developsPiece".localized)
        }

        if reasons.isEmpty {
            reasons.append("help.bestMove".localized)
            reasons.append("help.improvesPosition".localized)
        }

        return reasons.joined(separator: "\n")
    }
}
