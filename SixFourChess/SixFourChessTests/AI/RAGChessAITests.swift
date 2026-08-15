import Testing
import Foundation
@testable import SixFour

@MainActor
@Suite struct RAGChessAITests {

    /// Horloge de test : la première lecture initialise la recherche à zéro,
    /// les suivantes indiquent que son budget est expiré.
    nonisolated final class ExpiredBudgetTimeProvider: SearchTimeProviding, @unchecked Sendable {
        private let lock = NSLock()
        private var readCount = 0

        nonisolated func now() -> CFAbsoluteTime {
            lock.lock()
            defer { lock.unlock() }
            readCount += 1
            return readCount == 1 ? 0 : 10_000
        }
    }

    /// Horloge figée pour les tests de qualité des coups. Ces tests valident
    /// la recherche, pas les performances variables du matériel CI.
    private struct FrozenTimeProvider: SearchTimeProviding {
        nonisolated func now() -> CFAbsoluteTime { 0 }
    }

    /// Helper : crée une RAGChessAI minimale (sans NNUE, sans vectorStore).
    /// Utilise l'évaluation heuristique en fallback.
    private func makeRAGAI(
        difficulty: AIDifficulty = .medium,
        color: PieceColor = .white,
        timeProvider: any SearchTimeProviding = FrozenTimeProvider()
    ) -> RAGChessAI {
        let encoder = BoardEncoder()
        return RAGChessAI(
            difficulty: difficulty,
            color: color,
            encoder: encoder,
            openingBook: nil,
            nnueEvaluator: nil,
            vectorStore: nil,
            timeProvider: timeProvider
        )
    }

    // MARK: - findBestMove

    /// findBestMove doit retourner un coup non-nil sur la position initiale.
    @Test func findBestMoveReturnsNonNil() async {
        let ai = makeRAGAI(color: .white)
        let board = ChessBoard()
        let move = await ai.findBestMove(for: board)
        #expect(move != nil, "findBestMove doit retourner un coup pour la position initiale")
    }

    /// Le coup retourné doit être un coup légal.
    @Test func findBestMoveReturnsLegalMove() async {
        let ai = makeRAGAI(color: .white)
        let board = ChessBoard()
        let legalMoves = board.getAllLegalMoves(for: .white)

        if let move = await ai.findBestMove(for: board) {
            // Comparer par from/to/promotion car Move a un UUID id unique
            let matchesLegal = legalMoves.contains {
                $0.from == move.from && $0.to == move.to && $0.promotionType == move.promotionType
            }
            #expect(matchesLegal, "Le coup retourné doit correspondre à un coup légal")
        }
    }

    /// findBestMove doit fonctionner pour les noirs aussi.
    @Test func findBestMoveWorksForBlack() async throws {
        let ai = makeRAGAI(color: .black)
        // Position après 1.e4 (c'est aux noirs de jouer)
        let board = ChessBoard()
        let pawn = board.piece(at: pos("e2"))!
        let whiteMove = Move(from: pos("e2"), to: pos("e4"), piece: pawn)
        board.makeMove(whiteMove)

        let move = await ai.findBestMove(for: board)
        #expect(move != nil, "findBestMove doit retourner un coup pour les noirs")
    }

    /// findBestMove doit retourner nil pour une position sans coups légaux (pat).
    @Test func findBestMoveReturnsNilOnStalemate() async throws {
        let ai = makeRAGAI(color: .black)
        let board = try ChessBoard(fen: TestFEN.stalemate)

        let move = await ai.findBestMove(for: board)
        #expect(move == nil, "findBestMove doit retourner nil en situation de pat")
    }

    // MARK: - Détection de phase

    /// La position initiale doit être détectée comme ouverture.
    @Test func detectPhaseStartingIsOpening() async {
        let ai = makeRAGAI()
        let board = ChessBoard()
        let phase = await ai.detectPhase(state: board.state)
        #expect(phase == .opening, "La position initiale doit être en phase d'ouverture")
    }

    /// Une position avec peu de matériel doit être détectée comme finale.
    @Test func detectPhaseEndgame() async throws {
        let ai = makeRAGAI()
        // Roi + tour vs roi
        let board = try ChessBoard(fen: "4k3/8/8/8/8/8/8/R3K3 w - - 0 1")
        let phase = await ai.detectPhase(state: board.state)
        #expect(phase == .endgame, "Roi + tour vs roi doit être en finale")
    }

    // MARK: - Niveaux de difficulté

    /// Tous les niveaux de difficulté doivent produire un coup valide.
    @Test func allDifficultiesProduceMoves() async {
        let board = ChessBoard()

        for difficulty in [AIDifficulty.easy, .medium, .hard, .expert] {
            let ai = makeRAGAI(difficulty: difficulty, color: .white)
            let move = await ai.findBestMove(for: board)
            #expect(move != nil, "Difficulté \(difficulty) doit retourner un coup")
        }
    }

    // MARK: - Qualité des coups par niveau de difficulté

    /// Expert doit capturer une dame non défendue.
    /// Position : cavalier noir f5 peut capturer dame blanche d4 (non défendue).
    @Test func expertCapturesFreeQueen() async throws {
        // Cavalier f5 → d4 (capture dame) : delta (1, -2) = coup cavalier valide
        let board = try ChessBoard(fen: "4k3/8/8/5n2/3Q4/8/8/4K3 b - - 0 1")
        let ai = makeRAGAI(difficulty: .expert, color: .black)

        let move = await ai.findBestMove(for: board)
        #expect(move != nil, "Expert doit retourner un coup")
        #expect(move?.capturedPiece != nil,
                "Expert doit capturer la dame non défendue, pas jouer un coup passif")
        if let move = move {
            #expect(move.to == pos("d4"),
                    "Expert doit capturer la dame en d4 (a joué \(move.notation))")
        }
    }

    /// TOUS les niveaux doivent capturer une pièce non défendue.
    /// Position : tour noire a4 peut capturer tour blanche d4 sur la même rangée.
    @Test func allLevelsCaptureHangingPiece() async throws {
        let board = try ChessBoard(fen: "4k3/8/8/8/r2R4/8/8/4K3 b - - 0 1")

        for difficulty in [AIDifficulty.easy, .medium, .hard, .expert] {
            let ai = makeRAGAI(difficulty: difficulty, color: .black)
            let move = await ai.findBestMove(for: board)
            #expect(move != nil, "\(difficulty) doit retourner un coup")
            #expect(move?.capturedPiece != nil,
                    "\(difficulty) doit capturer la tour non défendue (a joué \(move?.notation ?? "nil"))")
        }
    }

    /// Expert doit trouver une fourchette de cavalier (attaque roi + tour).
    /// Position : cavalier e4 peut aller en d2 → attaque roi f1 ET tour b1.
    @Test func expertFindsKnightFork() async throws {
        let board = try ChessBoard(fen: "4k3/8/8/8/4n3/8/8/1R3K2 b - - 0 1")
        let ai = makeRAGAI(difficulty: .expert, color: .black)

        let move = await ai.findBestMove(for: board)
        #expect(move != nil, "Expert doit retourner un coup")
        if let move = move {
            // La fourchette est Nc4-d2 (attaque roi f1 + tour b1)
            #expect(move.from == pos("e4") && move.to == pos("d2"),
                    "Expert doit jouer la fourchette Ne4-d2 (a joué \(move.notation))")
        }
    }

    /// Expert ne doit pas "shuffler" les pièces quand il gagne largement.
    /// Position : noirs ont dame + roi vs roi + pion. Doit capturer le pion ou jouer activement.
    @Test func expertDoesNotShufflePiecesWhenWinning() async throws {
        let board = try ChessBoard(fen: "3qk3/8/8/8/8/3P4/8/4K3 b - - 0 1")
        let ai = makeRAGAI(difficulty: .expert, color: .black)

        let move = await ai.findBestMove(for: board)
        #expect(move != nil, "Expert doit retourner un coup")
        if let move = move {
            let corners = [pos("a1"), pos("a8"), pos("h1"), pos("h8")]
            let isPassiveCornerMove = corners.contains(where: { $0 == move.to })
                && move.capturedPiece == nil
            #expect(!isPassiveCornerMove,
                    "Expert ne doit pas jouer un coup passif vers un coin en gagnant (a joué \(move.notation))")
        }
    }

    /// Chaque niveau doit retourner un coup quand le budget de recherche expire.
    /// L'horloge injectée rend ce test indépendant de la charge de la machine CI.
    @Test func eachDifficultyCompletesWithinTimeBudget() async {
        let board = ChessBoard()

        for difficulty in [AIDifficulty.easy, .medium, .hard, .expert] {
            let ai = makeRAGAI(
                difficulty: difficulty,
                color: .white,
                timeProvider: ExpiredBudgetTimeProvider()
            )
            let move = await ai.findBestMove(for: board)
            #expect(move != nil, "\(difficulty) doit retourner un coup")
        }
    }

    /// Expert doit trouver un mat en 1 coup.
    /// Position : tour blanche a1 joue Ra1-a8# (mat au fond).
    @Test func expertFindsBackRankMate() async throws {
        // Roi noir g8, pions f7/g7/h7 bloquent. Tour a1 → a8 = mat.
        let board = try ChessBoard(fen: "6k1/5ppp/8/8/8/8/8/R3K3 w - - 0 1")
        let ai = makeRAGAI(difficulty: .expert, color: .white)

        let move = await ai.findBestMove(for: board)
        #expect(move != nil, "Expert doit retourner un coup")
        if let move = move {
            #expect(move.from == pos("a1") && move.to == pos("a8"),
                    "Expert doit jouer Ra1-a8# (mat en 1), a joué \(move.notation)")
        }
    }

    // MARK: - Check Extensions

    /// Check extension : le moteur doit trouver un mat même si la profondeur
    /// nominale est insuffisante, grâce à l'extension quand le roi est en échec.
    /// Position : Blanc Ra1, Ke1 vs Noir Kg8, pions f7/g7/h7 → Ra1-a8# (mat en 1).
    /// Avec hard (depth 4), le mat est trouvé même à faible profondeur.
    @Test func checkExtensionFindsMateInCheck() async throws {
        let board = try ChessBoard(fen: "6k1/5ppp/8/8/8/8/8/R3K3 w - - 0 1")
        let ai = makeRAGAI(difficulty: .hard, color: .white)
        let move = await ai.findBestMove(for: board)
        #expect(move != nil, "Doit trouver un coup")
        if let move = move {
            #expect(move.from == pos("a1") && move.to == pos("a8"),
                    "Doit jouer Ra1-a8# (mat), a joué \(move.notation)")
        }
    }

    // MARK: - Null-Move Pruning

    /// NMP ne doit pas casser la correction : avec un avantage matériel clair,
    /// le moteur doit quand même trouver un bon coup.
    @Test func nullMovePruningDoesNotBreakCorrectness() async throws {
        // Blancs ont dame + tour + roi vs roi noir seul → doit jouer un coup valide
        let board = try ChessBoard(fen: "4k3/8/8/8/8/8/8/Q3K2R w K - 0 1")
        let ai = makeRAGAI(difficulty: .hard, color: .white)
        let move = await ai.findBestMove(for: board)
        #expect(move != nil, "NMP ne doit pas empêcher de trouver un coup")
    }

    /// En finale roi+pions, le NMP doit être skippé (risque de zugzwang).
    /// Le moteur doit quand même trouver un coup.
    @Test func nmpSkippedInKingPawnEndgame() async throws {
        let board = try ChessBoard(fen: "4k3/4p3/8/8/8/8/4P3/4K3 w - - 0 1")
        let ai = makeRAGAI(difficulty: .hard, color: .white)
        let move = await ai.findBestMove(for: board)
        #expect(move != nil, "Doit trouver un coup en finale roi+pion (NMP skippé)")
    }

    // MARK: - Killer Moves

    /// Killer moves ne doivent pas casser la capture évidente.
    /// Position avec dame blanche non défendue → l'IA noire expert doit capturer.
    @Test func killerMovesDoNotBreakCorrectness() async throws {
        let board = try ChessBoard(fen: "4k3/8/8/5n2/3Q4/8/8/4K3 b - - 0 1")
        let ai = makeRAGAI(difficulty: .expert, color: .black)
        let move = await ai.findBestMove(for: board)
        #expect(move?.capturedPiece != nil,
                "Doit capturer la dame non défendue avec killer moves actifs (a joué \(move?.notation ?? "nil"))")
    }

    // MARK: - Opening Book intégré

    /// Si un opening book est fourni, le coup doit venir du book en ouverture.
    @Test func openingBookUsedInOpening() async throws {
        guard let bookURL = Bundle.main.url(forResource: "opening_book", withExtension: "bin") else {
            Issue.record("opening_book.bin introuvable")
            return
        }

        let book = try OpeningBook(url: bookURL)
        let encoder = BoardEncoder()
        let ai = RAGChessAI(
            difficulty: .hard,  // hard = useOpeningBook + useBestBookMove
            color: .white,
            encoder: encoder,
            openingBook: book,
            nnueEvaluator: nil,
            vectorStore: nil
        )

        let board = ChessBoard()
        let move = await ai.findBestMove(for: board)
        #expect(move != nil, "Avec un book, findBestMove doit retourner un coup en ouverture")

        // Vérifier que c'est un coup légal (comparaison par from/to/promotion, pas UUID)
        let legalMoves = board.getAllLegalMoves(for: .white)
        if let move = move {
            let matchesLegal = legalMoves.contains {
                $0.from == move.from && $0.to == move.to && $0.promotionType == move.promotionType
            }
            #expect(matchesLegal, "Le coup book doit correspondre à un coup légal")
        }
    }
}
