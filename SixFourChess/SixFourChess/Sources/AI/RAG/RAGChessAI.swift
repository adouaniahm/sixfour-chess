//
//  RAGChessAI.swift
//  SixFourChess
//
//  RAG-backed chess AI.
//  Drop-in replacement for `ChessAI` with the same `findBestMove(for:)` API.
//  Uses opening book lookup, position retrieval, and negamax evaluation.
//

import Foundation
import CoreML

// MARK: - Support Types

/// Injected time source used to make budget tests deterministic.
protocol SearchTimeProviding: Sendable {
    nonisolated func now() -> CFAbsoluteTime
}

struct SystemSearchTimeProvider: SearchTimeProviding {
    nonisolated func now() -> CFAbsoluteTime {
        CFAbsoluteTimeGetCurrent()
    }
}

/// Game phase used to select the retrieval strategy.
nonisolated enum GamePhase: Sendable {
    /// Opening: fullMoveNumber ≤ 12 and near-complete material.
    case opening
    /// Middle game: between opening and endgame.
    case middleGame
    /// Endgame: total material excluding kings is below 2600 centipawns.
    case endgame
}

/// Transposition table entry keyed by Zobrist hash.
nonisolated struct TranspositionEntry: Sendable {
    /// Node type: exact, lower bound, or upper bound.
    enum NodeType: Sendable {
        case exact
        case lowerBound
        case upperBound
    }

    let score: Int
    let depth: Int
    let nodeType: NodeType
    let bestMove: Move?
}

/// RAG configuration for one difficulty level.
nonisolated struct RAGDifficultyConfig: Sendable {
    /// Negamax search depth.
    let searchDepth: Int
    /// Whether to use the opening book.
    let useOpeningBook: Bool
    /// Book selection mode: true = best move, false = weighted random.
    let useBestBookMove: Bool
    /// Whether to use retrieval bias.
    let useRAGBias: Bool
    /// Retrieval bias weight in [0.0, 1.0].
    let ragBiasWeight: Double
    /// Maximum search time budget in seconds.
    let timeBudget: Double
    /// Deterministic evaluation noise in centipawns.
    let evaluationNoise: Int

    /// Preset configuration for each difficulty.
    static func config(for difficulty: AIDifficulty) -> RAGDifficultyConfig {
        switch difficulty {
        case .easy:
            return RAGDifficultyConfig(
                searchDepth: 2,
                useOpeningBook: false,
                useBestBookMove: false,
                useRAGBias: false,
                ragBiasWeight: 0.0,
                timeBudget: 0.3,
                evaluationNoise: 150  // ±1.5 pion → erreurs fréquentes
            )
        case .medium:
            return RAGDifficultyConfig(
                searchDepth: 3,
                useOpeningBook: true,
                useBestBookMove: false,
                useRAGBias: false,
                ragBiasWeight: 0.0,
                timeBudget: 0.8,
                evaluationNoise: 50   // ±0.5 pion → erreurs occasionnelles
            )
        case .hard:
            return RAGDifficultyConfig(
                searchDepth: 4,
                useOpeningBook: true,
                useBestBookMove: true,
                useRAGBias: true,
                ragBiasWeight: 0.10,
                timeBudget: 1.5,
                evaluationNoise: 0    // évaluation exacte
            )
        case .expert, .master:
            // .master uses Stockfish Cloud, but this is a fallback.
            return RAGDifficultyConfig(
                searchDepth: 5,
                useOpeningBook: true,
                useBestBookMove: true,
                useRAGBias: true,
                ragBiasWeight: 0.20,
                timeBudget: 3.5,
                evaluationNoise: 0    // évaluation exacte
            )
        }
    }
}

// MARK: - RAGChessAI

/// IA d'échecs augmentée par RAG.
///
/// Même interface que `ChessAI` : `findBestMove(for:) async -> Move?`
/// S'intègre directement dans `AIReduxMiddleware` comme remplacement drop-in.
///
/// Composants optionnels (graceful degradation) :
/// - Si `openingBook` est nil → pas de coups de livre
/// - Si `nnueEvaluator` n'a pas de modèle → fallback heuristique
/// - Si `vectorStore` n'est pas ouvert → pas de biais RAG
actor RAGChessAI {

    // MARK: - Dependencies

    /// Encodeur de positions (Zobrist hash + feature vectors)
    private let encoder: BoardEncoder
    /// Opening book Polyglot (nil si fichier non trouvé)
    private let openingBook: OpeningBook?
    /// Évaluateur NNUE CoreML (nil-safe : retourne nil si modèle non chargé)
    private let nnueEvaluator: NNUEEvaluator?
    /// Base vectorielle de positions (nil-safe : retourne [] si DB non ouverte)
    private let vectorStore: PositionVectorStore?
    /// Couleur contrôlée par cette IA
    private let color: PieceColor
    /// Configuration RAG pour le niveau de difficulté choisi
    private let config: RAGDifficultyConfig
    /// Horloge injectable utilisée pour les contrôles de budget de recherche.
    private let timeProvider: any SearchTimeProviding

    // MARK: - Transposition Table

    /// Table de transposition Zobrist.
    /// Clé : UInt64 hash (vs String FEN dans ChessAI → 30% plus rapide).
    /// Vidée à chaque appel findBestMove pour éviter les fuites mémoire.
    private var transpositionTable: [UInt64: TranspositionEntry] = [:]

    /// Constantes Negamax
    private static let infinity = 1_000_000_000
    private static let negInfinity = -1_000_000_000

    // MARK: - Local Search State

    /// Thread-safe Core ML model handle borrowed for local synchronous inference.
    private var searchModel: CoreMLModelHandle?

    /// MLMultiArray local pré-alloué (768 floats) pour l'inférence NNUE.
    /// Propre à RAGChessAI → pas de contention avec NNUEEvaluator.
    private var searchInput: MLMultiArray?

    /// Feature provider local réutilisable.
    private var searchProvider: MLDictionaryFeatureProvider?

    /// Cache NNUE local pour la recherche en cours.
    /// hash Zobrist → centipawns (score brut, perspective blanche).
    private var searchNNUECache: [UInt64: Int] = [:]

    /// Timestamp de début de la recherche courante.
    private var searchStartTime: CFAbsoluteTime = 0

    /// Flag levé quand le time budget est dépassé.
    /// Vérifié mid-search pour abandonner rapidement.
    private var searchTimedOut: Bool = false

    /// Compteur de nœuds visités dans la recherche courante.
    /// Utilisé pour vérifier le time budget périodiquement (tous les 512 nœuds)
    /// sans appeler l'horloge à chaque nœud.
    private var searchNodeCount: Int = 0

    /// Fréquence de vérification du timer (tous les N nœuds).
    private static let timeCheckInterval = 512

    /// Killer moves : 2 coups silencieux par ply qui ont causé un cutoff beta.
    /// Indexés par ply (distance depuis la racine). Stockés comme (from, to)
    /// pour éviter les problèmes d'égalité UUID de Move.
    private var searchKillerMoves: [[(from: Position, to: Position)?]] = []

    /// Multiplicateur pour le ply maximum (limite les check extensions).
    private static let maxPlyMultiplier = 3

    // MARK: - Heuristic Evaluation Tables

    /// Table pion : bonus positionnel par case (perspective blanche, row 0 = rang 8)
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

    /// Table cavalier : bonus positionnel (centre = fort)
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

    /// Table roi milieu de partie : sécurité = rester sur le flanc
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

    /// Table tour : colonnes centrales et 7ème rangée (pénétration)
    private static let rookTable: [[Int]] = [
        [ 0,  0,  0,  0,  0,  0,  0,  0],
        [ 5, 10, 10, 10, 10, 10, 10,  5],
        [-5,  0,  0,  0,  0,  0,  0, -5],
        [-5,  0,  0,  0,  0,  0,  0, -5],
        [-5,  0,  0,  0,  0,  0,  0, -5],
        [-5,  0,  0,  0,  0,  0,  0, -5],
        [-5,  0,  0,  0,  0,  0,  0, -5],
        [ 0,  0,  0,  5,  5,  0,  0,  0]
    ]

    /// Table fou : diagonales longues, éviter les bords
    private static let bishopTable: [[Int]] = [
        [-20,-10,-10,-10,-10,-10,-10,-20],
        [-10,  0,  0,  0,  0,  0,  0,-10],
        [-10,  0,  5, 10, 10,  5,  0,-10],
        [-10,  5,  5, 10, 10,  5,  5,-10],
        [-10,  0, 10, 10, 10, 10,  0,-10],
        [-10, 10, 10, 10, 10, 10, 10,-10],
        [-10,  5,  0,  0,  0,  0,  5,-10],
        [-20,-10,-10,-10,-10,-10,-10,-20]
    ]

    /// Table dame : centre préféré, pas trop tôt sur les bords
    private static let queenTable: [[Int]] = [
        [-20,-10,-10, -5, -5,-10,-10,-20],
        [-10,  0,  0,  0,  0,  0,  0,-10],
        [-10,  0,  5,  5,  5,  5,  0,-10],
        [ -5,  0,  5,  5,  5,  5,  0, -5],
        [  0,  0,  5,  5,  5,  5,  0, -5],
        [-10,  5,  5,  5,  5,  5,  0,-10],
        [-10,  0,  5,  0,  0,  0,  0,-10],
        [-20,-10,-10, -5, -5,-10,-10,-20]
    ]

    // MARK: - Initialization

    /// Crée une instance RAGChessAI.
    ///
    /// - Parameters:
    ///   - difficulty: Niveau de difficulté (détermine depth, book, RAG bias).
    ///   - color: Couleur contrôlée par cette IA.
    ///   - encoder: Encodeur Zobrist/feature partagé.
    ///   - openingBook: Book Polyglot (optionnel).
    ///   - nnueEvaluator: Évaluateur NNUE CoreML (optionnel).
    ///   - vectorStore: Base de positions SQLite (optionnel).
    init(
        difficulty: AIDifficulty,
        color: PieceColor,
        encoder: BoardEncoder,
        openingBook: OpeningBook? = nil,
        nnueEvaluator: NNUEEvaluator? = nil,
        vectorStore: PositionVectorStore? = nil,
        timeProvider: any SearchTimeProviding = SystemSearchTimeProvider()
    ) {
        self.encoder = encoder
        self.openingBook = openingBook
        self.nnueEvaluator = nnueEvaluator
        self.vectorStore = vectorStore
        self.color = color
        self.config = RAGDifficultyConfig.config(for: difficulty)
        self.timeProvider = timeProvider
    }

    // MARK: - Public Interface

    /// Trouve le meilleur coup pour la position donnée.
    ///
    /// Pipeline :
    /// 1. Détecte la phase (ouverture/milieu/finale)
    /// 2. Tente un coup de livre si en ouverture
    /// 3. Récupère un biais RAG si en milieu/finale
    /// 4. Lance Negamax itératif avec évaluation NNUE/heuristique
    ///
    /// Optimisé : extrait `ChessState` une seule fois depuis `ChessBoard` (@MainActor),
    /// puis tout le negamax opère sur le struct `ChessState` (synchrone, 0 await pour le jeu).
    ///
    /// - Parameter board: L'échiquier courant.
    /// - Returns: Le meilleur coup trouvé, ou nil si aucun coup légal.
    func findBestMove(for board: ChessBoard) async -> Move? {
        // ── Setup : extraire l'état et préparer la recherche ──
        let state = await board.state
        let legalMoves = state.getAllLegalMoves(for: color)

        transpositionTable.removeAll(keepingCapacity: true)
        searchNNUECache.removeAll(keepingCapacity: true)
        searchTimedOut = false
        searchNodeCount = 0

        // Reset killer moves pour la nouvelle recherche
        let maxPly = config.searchDepth * Self.maxPlyMultiplier
        searchKillerMoves = Array(repeating: [nil, nil], count: maxPly + 1)

        guard !legalMoves.isEmpty else { return nil }

        // ── Emprunter le modèle NNUE pour inférence locale synchrone ──
        // 1 seul await vers NNUEEvaluator, puis TOUT le negamax est synchrone.
        await setupLocalNNUE()
        print("[RAGChessAI] NNUE model: \(searchModel != nil ? "✅ loaded" : "❌ NOT available → heuristic fallback")")
        print("[RAGChessAI] Config: depth=\(config.searchDepth) timeBudget=\(config.timeBudget)s noise=\(config.evaluationNoise) legalMoves=\(legalMoves.count)")

        // ── Étape 1 : Détection de phase ──
        let phase = detectPhase(state: state)

        // ── Étape 2 : Tentative opening book ──
        if phase == .opening && config.useOpeningBook, let book = openingBook {
            let hash = encoder.zobristHash(for: state)
            let bookMove: Move?
            if config.useBestBookMove {
                bookMove = await book.bestMove(hash: hash, state: state, legalMoves: legalMoves)
            } else {
                bookMove = await book.selectMove(hash: hash, state: state, legalMoves: legalMoves)
            }
            if let move = bookMove {
                return move
            }
        }

        // ── Étape 3 : Biais RAG (positions similaires) ──
        var ragBias: Int? = nil
        if config.useRAGBias, let store = vectorStore, await store.isOpen {
            let similar = await store.findSimilar(to: state, topK: 5, candidateCount: 200)
            ragBias = await store.aggregateBias(from: similar)
        }

        // ── Étape 4 : Negamax itératif — 100% SYNCHRONE ──

        // Anti-oscillation : trouver le dernier coup de l'IA pour détecter les ping-pongs.
        // moveHistoryDetailed : [..., AI_move, Player_move]
        // Le dernier coup de l'IA est à l'index count-2 (avant le coup du joueur).
        let aiLastMove: Move? = {
            let history = state.moveHistoryDetailed
            guard history.count >= 2 else { return nil }
            let candidate = history[history.count - 2]
            return candidate.piece.color == color ? candidate : nil
        }()

        var bestMoveSoFar: Move? = legalMoves.first
        searchStartTime = timeProvider.now()

        for currentDepth in 1...config.searchDepth {
            // Vérifier le time budget avant de lancer un nouveau depth
            if currentDepth > 1 {
                let elapsed = timeProvider.now() - searchStartTime
                if elapsed > config.timeBudget { break }
            }

            searchTimedOut = false
            var bestMoveInIteration: Move?
            var bestScore = Self.negInfinity

            let orderedMoves = orderMoves(legalMoves, priority: bestMoveSoFar)

            for move in orderedMoves {
                // Time check entre coups racine
                if timeProvider.now() - searchStartTime > config.timeBudget {
                    searchTimedOut = true
                    break
                }

                var nextState = state
                nextState.makeMove(move)

                // negamax est 100% synchrone — 0 actor hop
                // Window narrowing : beta = -bestScore pour élaguer les coups
                // qui ne peuvent pas battre le meilleur trouvé jusqu'ici.
                // Premier coup : bestScore = negInfinity → -bestScore = +infinity → fenêtre pleine.
                // Coups suivants : fenêtre étroite → élagage massif → ~10x plus rapide.
                let rawScore = -negamax(
                    state: nextState,
                    depth: currentDepth - 1,
                    ply: 1,
                    alpha: Self.negInfinity,
                    beta: -bestScore,
                    color: color.opposite,
                    ragBias: ragBias
                )

                // ── Anti-oscillation : pénaliser le coup inverse du dernier coup IA.
                // Si l'IA vient de jouer A→B et le meilleur coup est B→A (même pièce),
                // c'est un ping-pong inutile → pénalité de 200 centipawns (2 pions).
                // L'arbre de recherche interne reste intact ; seule la décision racine
                // est biaisée contre les oscillations.
                var score = rawScore
                if let lastMove = aiLastMove,
                   move.piece.type == lastMove.piece.type,
                   move.from == lastMove.to,
                   move.to == lastMove.from {
                    score -= 200
                }

                if score > bestScore {
                    bestScore = score
                    bestMoveInIteration = move
                }
            }

            // ── Log de fin d'itération ──
            let elapsed = timeProvider.now() - searchStartTime
            if let move = bestMoveInIteration {
                print("[RAGChessAI] depth=\(currentDepth) best=\(move.notation) score=\(bestScore) nodes=\(searchNodeCount) time=\(String(format: "%.2f", elapsed))s\(searchTimedOut ? " ⏱️TIMEOUT" : "")")
            }

            // Ne mettre à jour que si l'itération a pu se terminer
            if let move = bestMoveInIteration, !searchTimedOut {
                bestMoveSoFar = move
            }
            if searchTimedOut { break }
        }

        let totalTime = timeProvider.now() - searchStartTime
        if let move = bestMoveSoFar {
            print("[RAGChessAI] ✅ Selected: \(move.notation) (nodes=\(searchNodeCount) time=\(String(format: "%.2f", totalTime))s)")
        }

        return bestMoveSoFar
    }

    /// Emprunte le modèle CoreML depuis NNUEEvaluator et prépare
    /// les buffers locaux pour l'inférence synchrone.
    ///
    /// Appelée une seule fois au début de chaque findBestMove.
    /// Après cet appel, tout le negamax peut tourner sans `await`.
    private func setupLocalNNUE() async {
        guard let nnue = nnueEvaluator else {
            searchModel = nil
            searchInput = nil
            searchProvider = nil
            return
        }

        // 1 seul actor hop → NNUEEvaluator
        searchModel = await nnue.borrowModel()

        // Allouer les buffers locaux s'ils n'existent pas encore
        if searchInput == nil, searchModel != nil {
            if let multiArray = try? MLMultiArray(shape: [1, 768], dataType: .float32) {
                searchInput = multiArray
                searchProvider = try? MLDictionaryFeatureProvider(
                    dictionary: ["features": multiArray]
                )
            }
        }
    }

    // MARK: - Phase Detection

    /// Détermine la phase de la partie basée sur le matériel et le nombre de coups.
    ///
    /// Critères :
    /// - Ouverture : fullMoveNumber ≤ 12 et total matériel > 6000 (majorité des pièces)
    /// - Finale : total matériel (hors rois) < 2600 (≈ 2 tours + pions)
    /// - Milieu : tout le reste
    func detectPhase(state: ChessState) -> GamePhase {
        // Compter le matériel total (hors rois)
        var totalMaterial = 0
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = state.board[row][col], piece.type != .king {
                    totalMaterial += piece.type.value
                }
            }
        }

        // Finale si peu de matériel
        if totalMaterial < 2600 {
            return .endgame
        }

        // Ouverture si encore tôt et beaucoup de pièces
        if state.fullMoveNumber <= 12 && totalMaterial > 6000 {
            return .opening
        }

        return .middleGame
    }

    // MARK: - Negamax with Alpha-Beta Pruning

    /// Recherche Negamax avec élagage alpha-beta — 100% SYNCHRONE.
    ///
    /// Optimisations :
    /// - Opère sur `ChessState` (struct value-type) → 0 actor hop
    /// - Inférence NNUE locale via `searchModel` → 0 await
    /// - Late Move Reduction (LMR) : depth -2 pour les coups tardifs silencieux
    /// - Limites de coups agressives : 12/15/20 selon la depth restante
    /// - Time budget vérifié périodiquement pour limiter le coût de l'horloge
    ///
    /// - Parameters:
    ///   - state: Position à évaluer (struct value-type, synchrone).
    ///   - depth: Profondeur restante.
    ///   - ply: Distance depuis la racine (0 = racine).
    ///   - alpha: Borne inférieure.
    ///   - beta: Borne supérieure.
    ///   - color: Couleur du joueur courant.
    ///   - ragBias: Biais centipawns des positions similaires.
    ///   - allowNullMove: Autoriser le null-move pruning (false après un null-move).
    /// - Returns: Score en centipawns du point de vue de `color`.
    private func negamax(
        state: ChessState,
        depth: Int,
        ply: Int,
        alpha: Int,
        beta: Int,
        color: PieceColor,
        ragBias: Int?,
        allowNullMove: Bool = true
    ) -> Int {
        // ── Hash Zobrist : calculé une seule fois, réutilisé partout ──
        let hash = encoder.zobristHash(for: state)

        // ── Time budget : vérification périodique ──
        searchNodeCount += 1
        if searchTimedOut {
            return evaluatePositionSync(state: state, hash: hash, for: color, ragBias: ragBias)
        }
        if searchNodeCount & (Self.timeCheckInterval - 1) == 0 {
            if timeProvider.now() - searchStartTime > config.timeBudget {
                searchTimedOut = true
                return evaluatePositionSync(state: state, hash: hash, for: color, ragBias: ragBias)
            }
        }

        // ── Check extension : ne pas tomber en quiescence pendant un échec ──
        // Si le roi est en échec, on étend la recherche d'1 ply pour voir
        // toutes les réponses à l'échec. Limité par maxPly pour éviter l'explosion.
        let inCheck = state.isInCheck(color: color)
        var depth = depth
        let maxPly = config.searchDepth * Self.maxPlyMultiplier
        if inCheck && ply < maxPly {
            depth += 1
        }

        // ── Feuille : Quiescence Search ──
        // Au lieu d'évaluer statiquement, on explore les captures pour
        // éliminer l'effet horizon (rater un échange en cours).
        if depth == 0 {
            return quiescence(
                state: state,
                hash: hash,
                alpha: alpha,
                beta: beta,
                color: color,
                ragBias: ragBias
            )
        }

        // ── Lookup table de transposition ──
        if let entry = transpositionTable[hash], entry.depth >= depth {
            switch entry.nodeType {
            case .exact:
                return entry.score
            case .lowerBound:
                if entry.score >= beta { return entry.score }
            case .upperBound:
                if entry.score <= alpha { return entry.score }
            }
        }

        // ── Null-Move Pruning (NMP) ──
        // Si passer son tour (null move) donne encore un score >= beta,
        // la position est si bonne qu'on peut pruner sans chercher les vrais coups.
        // Placé AVANT getAllLegalMoves (opération la plus coûteuse) pour max savings.
        if depth >= 3 && !inCheck && allowNullMove {
            // Anti-zugzwang : skip si le camp n'a que roi + pions
            let hasNonPawnMaterial: Bool = {
                for row in 0..<8 {
                    for col in 0..<8 {
                        if let piece = state.board[row][col],
                           piece.color == color,
                           piece.type != .king && piece.type != .pawn {
                            return true
                        }
                    }
                }
                return false
            }()

            if hasNonPawnMaterial {
                // Créer l'état "null move" : passer son tour
                var nullState = state
                nullState.currentPlayer = color.opposite
                nullState.enPassantTarget = nil  // EP invalide après un tour passé

                // R=2 : chercher à depth - 1 - R = depth - 3, zero window
                let nullScore = -negamax(
                    state: nullState,
                    depth: depth - 3,
                    ply: ply + 1,
                    alpha: -beta,
                    beta: -beta + 1,
                    color: color.opposite,
                    ragBias: ragBias,
                    allowNullMove: false  // Pas de double null-move
                )

                if nullScore >= beta {
                    return beta  // Prune : la position est trop bonne
                }
            }
        }

        // ── Générer les coups AVANT checkmate/stalemate ──
        // (isCheckmate/isStalemate appellent getAllLegalMoves en interne →
        //  les appeler séparément doublerait le travail sur chaque nœud)
        let legalMoves = state.getAllLegalMoves(for: color)
        if legalMoves.isEmpty {
            if inCheck {
                return -100_000 + ply  // mat : plus ply est petit, plus le mat est proche
            }
            return 0 // pat
        }

        let ttBestMove = transpositionTable[hash]?.bestMove
        let killers = ply < searchKillerMoves.count ? searchKillerMoves[ply] : nil
        let orderedMoves = orderMoves(legalMoves, priority: ttBestMove, killers: killers)

        // Limiter les coups silencieux selon la profondeur restante.
        // Les captures et promotions ne sont JAMAIS coupées — seuls les
        // coups "quiet" (sans capture ni promotion) sont limités.
        // Cela empêche de rater des captures gagnantes aux niveaux profonds.
        let maxQuietMoves: Int
        switch depth {
        case 5...: maxQuietMoves = 10
        case 4:    maxQuietMoves = 12
        case 3:    maxQuietMoves = 18
        default:   maxQuietMoves = orderedMoves.count
        }
        var movesToAnalyze: [Move] = []
        movesToAnalyze.reserveCapacity(orderedMoves.count)
        var quietCount = 0
        for move in orderedMoves {
            let isTactical = move.capturedPiece != nil || move.promotionType != nil
            if isTactical {
                movesToAnalyze.append(move)  // toujours inclure
            } else {
                quietCount += 1
                if quietCount <= maxQuietMoves {
                    movesToAnalyze.append(move)
                }
            }
        }

        let originalAlpha = alpha  // Sauvegarder AVANT la boucle pour le nodeType TT
        var alpha = alpha
        var maxScore = Self.negInfinity
        var bestMove: Move?

        for (index, move) in movesToAnalyze.enumerated() {
            var nextState = state
            nextState.makeMove(move)

            // Late Move Reduction (LMR) :
            // Les coups tardifs (rang ≥ 4) à depth ≥ 3 sont d'abord cherchés
            // avec une profondeur réduite. Si le score est prometteur (> alpha),
            // on relance à pleine profondeur.
            var score: Int
            let canReduceDepth = index >= 4 && depth >= 3
                && move.capturedPiece == nil && move.promotionType == nil

            if canReduceDepth {
                // Recherche réduite (depth - 2 au lieu de depth - 1)
                score = -negamax(
                    state: nextState,
                    depth: depth - 2,
                    ply: ply + 1,
                    alpha: -beta,
                    beta: -alpha,
                    color: color.opposite,
                    ragBias: ragBias
                )
                // Re-recherche à pleine profondeur si score prometteur
                if score > alpha {
                    score = -negamax(
                        state: nextState,
                        depth: depth - 1,
                        ply: ply + 1,
                        alpha: -beta,
                        beta: -alpha,
                        color: color.opposite,
                        ragBias: ragBias
                    )
                }
            } else {
                score = -negamax(
                    state: nextState,
                    depth: depth - 1,
                    ply: ply + 1,
                    alpha: -beta,
                    beta: -alpha,
                    color: color.opposite,
                    ragBias: ragBias
                )
            }

            if score > maxScore {
                maxScore = score
                bestMove = move
            }

            alpha = max(alpha, score)
            if alpha >= beta {
                // ── Killer move : stocker les coups silencieux qui causent un cutoff ──
                if move.capturedPiece == nil && move.promotionType == nil
                    && ply < searchKillerMoves.count {
                    let killerKey = (from: move.from, to: move.to)
                    // Décaler : slot 1 ← slot 0, slot 0 ← nouveau killer
                    if searchKillerMoves[ply][0] == nil
                        || searchKillerMoves[ply][0]!.from != killerKey.from
                        || searchKillerMoves[ply][0]!.to != killerKey.to {
                        searchKillerMoves[ply][1] = searchKillerMoves[ply][0]
                        searchKillerMoves[ply][0] = killerKey
                    }
                }
                break
            }
        }

        // ── Stocker dans la TT ──
        let nodeType: TranspositionEntry.NodeType
        if maxScore <= originalAlpha {
            nodeType = .upperBound
        } else if maxScore >= beta {
            nodeType = .lowerBound
        } else {
            nodeType = .exact
        }

        transpositionTable[hash] = TranspositionEntry(
            score: maxScore,
            depth: depth,
            nodeType: nodeType,
            bestMove: bestMove
        )

        return maxScore
    }

    // MARK: - Quiescence Search

    /// Recherche de quiescence — explore les captures au-delà de `depth == 0`.
    ///
    /// Élimine l'**effet horizon** : sans quiescence, le negamax s'arrête à
    /// `depth == 0` et évalue une position en plein milieu d'un échange de pièces,
    /// ce qui donne un score complètement faux.
    ///
    /// La quiescence ne cherche que les **captures et promotions** (pas les coups
    /// silencieux). Elle s'arrête quand la position est "calme" (plus de captures
    /// intéressantes) ou quand le time budget est dépassé.
    ///
    /// **Stand pat** : le score statique de la position courante sert de borne
    /// inférieure. Si la position est déjà bonne (standPat >= beta), on coupe
    /// immédiatement (null move observation).
    ///
    /// - Parameters:
    ///   - state: Position à évaluer.
    ///   - hash: Hash Zobrist pré-calculé.
    ///   - alpha: Borne inférieure α-β.
    ///   - beta: Borne supérieure α-β.
    ///   - color: Point de vue de l'évaluation.
    ///   - ragBias: Biais RAG optionnel.
    /// - Returns: Score en centipawns du point de vue de `color`.
    private func quiescence(
        state: ChessState,
        hash: UInt64,
        alpha: Int,
        beta: Int,
        color: PieceColor,
        ragBias: Int?
    ) -> Int {
        // ── Time budget check ──
        searchNodeCount += 1
        if searchTimedOut {
            return evaluatePositionSync(state: state, hash: hash, for: color, ragBias: ragBias)
        }
        if searchNodeCount & (Self.timeCheckInterval - 1) == 0 {
            if timeProvider.now() - searchStartTime > config.timeBudget {
                searchTimedOut = true
                return evaluatePositionSync(state: state, hash: hash, for: color, ragBias: ragBias)
            }
        }

        // ── Stand pat : évaluation statique comme borne inférieure ──
        let standPat = evaluatePositionSync(state: state, hash: hash, for: color, ragBias: ragBias)
        if standPat >= beta {
            return beta  // Position déjà trop bonne → cutoff
        }
        var alpha = max(alpha, standPat)

        // ── Delta pruning : si même capturer la dame ne suffit pas, abandonner ──
        // (optimisation : évite d'explorer des captures inutiles)
        if standPat + 1000 < alpha {
            return alpha
        }

        // ── Générer et ordonner les captures uniquement ──
        let allMoves = state.getAllLegalMoves(for: color)
        var captures: [Move] = []
        captures.reserveCapacity(allMoves.count)
        for move in allMoves {
            if move.capturedPiece != nil || move.promotionType != nil {
                captures.append(move)
            }
        }

        // Pas de captures → position calme → retourner le stand pat
        if captures.isEmpty {
            return alpha
        }

        let orderedCaptures = orderMoves(captures)

        for move in orderedCaptures {
            var nextState = state
            nextState.makeMove(move)
            let nextHash = encoder.zobristHash(for: nextState)

            let score = -quiescence(
                state: nextState,
                hash: nextHash,
                alpha: -beta,
                beta: -alpha,
                color: color.opposite,
                ragBias: ragBias
            )

            if score >= beta {
                return beta  // Cutoff β
            }
            alpha = max(alpha, score)
        }

        return alpha
    }

    // MARK: - Position Evaluation

    /// Évalue une position localement — 100% SYNCHRONE, 0 actor hop.
    ///
    /// Utilise le modèle CoreML emprunté (`searchModel`) et les buffers locaux
    /// pour l'inférence NNUE directe sur l'actor RAGChessAI.
    ///
    /// Fallback heuristique si le modèle n'est pas disponible.
    ///
    /// - Parameters:
    ///   - state: Position à évaluer.
    ///   - color: Point de vue de l'évaluation.
    ///   - ragBias: Biais centipawns des positions similaires.
    /// - Returns: Score en centipawns (positif = bon pour `color`).
    private func evaluatePositionSync(
        state: ChessState,
        hash: UInt64,
        for color: PieceColor,
        ragBias: Int?
    ) -> Int {
        // ── Cache NNUE : vérifier AVANT de calculer les features (768 floats) ──
        if let cached = searchNNUECache[hash] {
            let score = applyPerspectiveAndBlend(
                rawScore: cached, color: color, ragBias: ragBias
            )
            return applyEvaluationNoise(to: score, hash: hash)
        }

        guard let modelHandle = searchModel,
              let multiArray = searchInput,
              let provider = searchProvider else {
            return applyEvaluationNoise(
                to: evaluateHeuristic(state: state, for: color),
                hash: hash
            )
        }

        // ── Calculer features seulement si cache miss ──
        let features = encoder.featureVector(for: state)

        // ── Remplir MLMultiArray via dataPointer (0 boxing) ──
        let ptr = multiArray.dataPointer.bindMemory(to: Float.self, capacity: 768)
        for i in 0..<768 {
            ptr[i] = features[i]
        }

        // ── Prédiction CoreML synchrone (même thread/actor) ──
        guard let prediction = try? modelHandle.model.prediction(from: provider),
              let outputValue = prediction.featureValue(for: "evaluation"),
              let outputArray = outputValue.multiArrayValue else {
            return applyEvaluationNoise(
                to: evaluateHeuristic(state: state, for: color),
                hash: hash
            )
        }

        let rawNNUE = Int(outputArray[0].doubleValue * 100.0)

        // ── Blending adaptatif NNUE + Heuristique ──
        // Le modèle NNUE sature dans les positions extrêmes (> ±800cp) :
        // il retourne le même score pour toutes les variantes → l'IA ne peut
        // pas distinguer entre un bon et un mauvais coup.
        // Solution : blender avec l'évaluation heuristique (matériel + PST + bonus)
        // qui échelle naturellement avec le matériel.
        // Les deux scores sont white-relative avant blending.
        let heuristicWhite = evaluateHeuristic(state: state, for: .white)

        let absNNUE = abs(rawNNUE)
        let nnueWeight: Double
        if absNNUE <= 300 {
            nnueWeight = 0.8  // Position normale : NNUE fiable, léger apport heuristique
        } else if absNNUE <= 800 {
            // Interpolation linéaire : 0.8 à 300cp → 0.2 à 800cp
            nnueWeight = 0.8 - 0.6 * Double(absNNUE - 300) / 500.0
        } else {
            nnueWeight = 0.2  // Saturation NNUE : heuristique domine (80%)
        }

        let blendedScore = Int(
            Double(rawNNUE) * nnueWeight
            + Double(heuristicWhite) * (1.0 - nnueWeight)
        )
        searchNNUECache[hash] = blendedScore

        let score = applyPerspectiveAndBlend(
            rawScore: blendedScore, color: color, ragBias: ragBias
        )
        return applyEvaluationNoise(to: score, hash: hash)
    }

    /// Ajuste un score white-relative pour le point de vue de `color`,
    /// puis blend avec le biais RAG si fourni.
    private func applyPerspectiveAndBlend(
        rawScore: Int,
        color: PieceColor,
        ragBias: Int?
    ) -> Int {
        var score = color == .white ? rawScore : -rawScore

        if let bias = ragBias, config.ragBiasWeight > 0 {
            let adjustedBias = color == .white ? bias : -bias
            score = Int(
                Double(score) * (1.0 - config.ragBiasWeight)
                + Double(adjustedBias) * config.ragBiasWeight
            )
        }

        return score
    }

    /// Applique un bruit d'évaluation déterministe pour différencier les difficultés.
    ///
    /// Le bruit est basé sur le hash Zobrist de la position → même position = même bruit
    /// → cohérence avec la table de transposition.
    ///
    /// - Parameters:
    ///   - score: Score brut en centipawns.
    ///   - hash: Hash Zobrist de la position (source d'entropie déterministe).
    /// - Returns: Score bruité (inchangé si `evaluationNoise == 0`).
    private func applyEvaluationNoise(to score: Int, hash: UInt64) -> Int {
        guard config.evaluationNoise > 0 else { return score }
        // Bruit dans [-evaluationNoise, +evaluationNoise]
        // ex: noise=150 → range = 301, bruit ∈ [-150, +150]
        let range = UInt64(config.evaluationNoise * 2 + 1)
        let noise = Int(hash % range) - config.evaluationNoise
        return score + noise
    }

    /// Évaluation heuristique pure (pas de ML).
    ///
    /// Matériel + tables de position (toutes pièces) + bonus stratégiques :
    /// colonnes ouvertes, 7ème rangée, paire de fous, mobilité, sécurité du roi.
    private func evaluateHeuristic(state: ChessState, for color: PieceColor) -> Int {
        var score = 0
        // Compteurs pour les bonus stratégiques
        var friendlyBishops = 0
        var enemyBishops = 0
        // Colonnes avec pions (pour détection colonnes ouvertes/semi-ouvertes)
        var friendlyPawnCols: UInt8 = 0  // bitmask : bit i = pion ami sur colonne i
        var enemyPawnCols: UInt8 = 0     // bitmask : bit i = pion ennemi sur colonne i
        // Positions des tours amies pour bonus stratégiques
        var friendlyRooks: [(row: Int, col: Int)] = []
        // Position du roi ami et ennemi pour sécurité
        var friendlyKingPos: (row: Int, col: Int) = (7, 4)
        var enemyKingPos: (row: Int, col: Int) = (0, 4)

        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = state.board[row][col] {
                    var pieceScore = piece.type.value

                    // Bonus positionnel (perspective blanche)
                    let tableRow = piece.color == .white ? row : 7 - row
                    switch piece.type {
                    case .pawn:
                        pieceScore += Self.pawnTable[tableRow][col]
                        if piece.color == color {
                            friendlyPawnCols |= (1 << col)
                        } else {
                            enemyPawnCols |= (1 << col)
                        }
                    case .knight:
                        pieceScore += Self.knightTable[tableRow][col]
                    case .bishop:
                        pieceScore += Self.bishopTable[tableRow][col]
                        if piece.color == color {
                            friendlyBishops += 1
                        } else {
                            enemyBishops += 1
                        }
                    case .rook:
                        pieceScore += Self.rookTable[tableRow][col]
                        if piece.color == color {
                            friendlyRooks.append((row, col))
                        }
                    case .queen:
                        pieceScore += Self.queenTable[tableRow][col]
                    case .king:
                        pieceScore += Self.kingMiddleGameTable[tableRow][col]
                        if piece.color == color {
                            friendlyKingPos = (row, col)
                        } else {
                            enemyKingPos = (row, col)
                        }
                    }

                    score += piece.color == color ? pieceScore : -pieceScore
                }
            }
        }

        // ── Bonus stratégiques ──

        // Contrôle du centre
        let centerSquares = [(3, 3), (3, 4), (4, 3), (4, 4)]
        for (r, c) in centerSquares {
            if let piece = state.board[r][c], piece.color == color {
                score += 5
            }
        }

        // Paire de fous : avantage positionnel reconnu (~30cp)
        if friendlyBishops >= 2 { score += 30 }
        if enemyBishops >= 2 { score -= 30 }

        // Bonus tours : colonnes ouvertes et semi-ouvertes
        let seventhRank = color == .white ? 1 : 6
        for rook in friendlyRooks {
            let colBit: UInt8 = 1 << rook.col
            let hasFriendlyPawn = (friendlyPawnCols & colBit) != 0
            let hasEnemyPawn = (enemyPawnCols & colBit) != 0

            if !hasFriendlyPawn && !hasEnemyPawn {
                score += 25  // Colonne ouverte : aucun pion
            } else if !hasFriendlyPawn {
                score += 15  // Colonne semi-ouverte : pas de pion ami
            }

            // Tour sur la 7ème rangée (pénétration)
            if rook.row == seventhRank {
                score += 20
            }
        }

        // NOTE : la mobilité (getAllLegalMoves × 2) a été retirée car trop coûteuse
        // en fallback heuristique. Les tables de pièces couvrent déjà la centralisation.
        // getAllLegalMoves est l'opération la plus chère ; l'appeler 2× par feuille
        // rendait la recherche ~3× plus lente → time budget atteint trop tôt.

        // ── Sécurité du roi : bouclier de pions ──
        // Si le roi est roqué (coin), vérifier les pions protecteurs devant lui.
        // Chaque pion en place = +15cp, pion avancé = +5cp, pion absent = 0.
        score += evaluateKingSafety(
            state: state, kingPos: friendlyKingPos, color: color
        )
        score -= evaluateKingSafety(
            state: state, kingPos: enemyKingPos, color: color.opposite
        )

        return score
    }

    /// Évalue la sécurité du roi basée sur le bouclier de pions.
    ///
    /// Vérifie les 3 cases devant le roi roqué. Chaque pion ami présent
    /// sur sa case initiale rapporte 15cp, avancé d'une case rapporte 5cp.
    ///
    /// - Returns: Bonus de sécurité en centipawns (0 si roi au centre).
    private func evaluateKingSafety(
        state: ChessState,
        kingPos: (row: Int, col: Int),
        color: PieceColor
    ) -> Int {
        // Le bouclier n'a de sens que si le roi est roqué sur un flanc
        let isKingsideWhite = color == .white && kingPos.row == 7 && kingPos.col >= 6
        let isQueensideWhite = color == .white && kingPos.row == 7 && kingPos.col <= 2
        let isKingsideBlack = color == .black && kingPos.row == 0 && kingPos.col >= 6
        let isQueensideBlack = color == .black && kingPos.row == 0 && kingPos.col <= 2

        guard isKingsideWhite || isQueensideWhite || isKingsideBlack || isQueensideBlack else {
            return 0  // Roi au centre → pas de bonus bouclier
        }

        var safety = 0
        // Colonnes du bouclier (3 colonnes devant le roi)
        let shieldCols: [Int]
        if isKingsideWhite || isKingsideBlack {
            shieldCols = [5, 6, 7]  // f, g, h
        } else {
            shieldCols = [0, 1, 2]  // a, b, c
        }

        let pawnInitialRow = color == .white ? 6 : 1  // rang 2 pour blanc, rang 7 pour noir
        let pawnAdvancedRow = color == .white ? 5 : 2  // rang 3 pour blanc, rang 6 pour noir

        for col in shieldCols {
            if let piece = state.board[pawnInitialRow][col],
               piece.type == .pawn && piece.color == color {
                safety += 15  // Pion en place sur sa case initiale
            } else if let piece = state.board[pawnAdvancedRow][col],
                      piece.type == .pawn && piece.color == color {
                safety += 5   // Pion avancé d'une case (moins bon)
            }
            // Pas de pion = 0 → brèche dans le bouclier
        }

        return safety
    }

    // MARK: - Move Ordering

    /// Ordonne les coups pour maximiser l'efficacité de l'élagage α-β.
    ///
    /// Ordre de priorité :
    /// 1. Coup prioritaire (meilleur de l'itération précédente ou de la TT)
    /// 2. Promotions dame (+900)
    /// 3. Captures MVV-LVA (Most Valuable Victim - Least Valuable Attacker)
    /// 4. Killer moves (+800) — coups silencieux ayant causé un cutoff à ce ply
    /// 5. Coups vers le centre
    ///
    /// Un bon ordonnancement peut réduire l'arbre de recherche de 90%+.
    private func orderMoves(
        _ moves: [Move],
        priority: Move? = nil,
        killers: [(from: Position, to: Position)?]? = nil
    ) -> [Move] {
        var scored: [(move: Move, score: Int)] = []
        scored.reserveCapacity(moves.count)

        for move in moves {
            var score = 0

            // MVV-LVA : capturer une pièce forte avec une pièce faible = bon
            if let captured = move.capturedPiece {
                score += captured.type.value * 10 - move.piece.type.value
            }

            // Promotions dame = très bon
            if move.promotionType == .queen {
                score += 900
            }

            // Killer moves : coups silencieux qui ont causé un cutoff beta à ce ply.
            // Score +800 : entre captures (~900+) et centre (~80).
            if let killers = killers,
               move.capturedPiece == nil && move.promotionType == nil {
                for killer in killers {
                    if let k = killer, move.from == k.from && move.to == k.to {
                        score += 800
                        break
                    }
                }
            }

            // Coups vers le centre = légèrement bon
            let centerDistance = abs(move.to.row - 4) + abs(move.to.col - 4)
            score += (8 - centerDistance) * 10

            scored.append((move, score))
        }

        var sorted = scored.sorted { $0.score > $1.score }.map(\.move)

        // Placer le coup prioritaire en premier (crucial pour l'iterative deepening)
        if let prio = priority, let idx = sorted.firstIndex(of: prio) {
            sorted.remove(at: idx)
            sorted.insert(prio, at: 0)
        }

        return sorted
    }
}
