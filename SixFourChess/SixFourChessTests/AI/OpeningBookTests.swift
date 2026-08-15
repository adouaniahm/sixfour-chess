import Testing
import Foundation
@testable import SixFour

@MainActor
@Suite struct OpeningBookTests {

    /// Le fichier opening_book.bin doit être présent dans le bundle de test.
    @Test func openingBookFileExists() {
        let bookURL = Bundle.main.url(forResource: "opening_book", withExtension: "bin")
        #expect(bookURL != nil, "opening_book.bin introuvable dans le bundle")
    }

    /// L'opening book doit se charger sans erreur.
    @Test func openingBookLoads() throws {
        guard let bookURL = Bundle.main.url(forResource: "opening_book", withExtension: "bin") else {
            Issue.record("opening_book.bin introuvable")
            return
        }
        let book = try OpeningBook(url: bookURL)
        _ = book  // Pas de crash = succès
    }

    /// La position initiale doit avoir au moins 1 entrée dans le book.
    @Test func startingPositionHasEntries() async throws {
        guard let bookURL = Bundle.main.url(forResource: "opening_book", withExtension: "bin") else {
            Issue.record("opening_book.bin introuvable")
            return
        }
        let book = try OpeningBook(url: bookURL)
        let encoder = BoardEncoder()
        let board = ChessBoard()

        let state = board.state
        let hash = encoder.zobristHash(for: state)
        let legalMoves = board.getAllLegalMoves(for: .white)

        let move = await book.selectMove(hash: hash, state: state, legalMoves: legalMoves)
        #expect(move != nil, "L'opening book devrait avoir au moins un coup pour la position initiale")
    }

    /// Le coup sélectionné doit être un coup légal.
    @Test func bookMoveIsLegal() async throws {
        guard let bookURL = Bundle.main.url(forResource: "opening_book", withExtension: "bin") else {
            Issue.record("opening_book.bin introuvable")
            return
        }
        let book = try OpeningBook(url: bookURL)
        let encoder = BoardEncoder()
        let board = ChessBoard()

        let state = board.state
        let hash = encoder.zobristHash(for: state)
        let legalMoves = board.getAllLegalMoves(for: .white)

        if let move = await book.selectMove(hash: hash, state: state, legalMoves: legalMoves) {
            // Comparer par from/to/promotion car Move a un UUID id unique
            let matchesLegal = legalMoves.contains {
                $0.from == move.from && $0.to == move.to && $0.promotionType == move.promotionType
            }
            #expect(matchesLegal, "Le coup du book doit correspondre à un coup légal")
        }
    }

    /// bestMove et selectMove doivent tous deux retourner un coup pour la position initiale.
    @Test func bestMoveReturnsMove() async throws {
        guard let bookURL = Bundle.main.url(forResource: "opening_book", withExtension: "bin") else {
            Issue.record("opening_book.bin introuvable")
            return
        }
        let book = try OpeningBook(url: bookURL)
        let encoder = BoardEncoder()
        let board = ChessBoard()

        let state = board.state
        let hash = encoder.zobristHash(for: state)
        let legalMoves = board.getAllLegalMoves(for: .white)

        let best = await book.bestMove(hash: hash, state: state, legalMoves: legalMoves)
        #expect(best != nil, "bestMove devrait retourner un coup pour la position initiale")
    }

    /// Un hash inconnu ne doit pas retourner de coup (graceful nil).
    @Test func unknownHashReturnsNil() async throws {
        guard let bookURL = Bundle.main.url(forResource: "opening_book", withExtension: "bin") else {
            Issue.record("opening_book.bin introuvable")
            return
        }
        let book = try OpeningBook(url: bookURL)
        let board = ChessBoard()
        let state = board.state
        let legalMoves = board.getAllLegalMoves(for: .white)

        // Hash bidon : aucune position ne devrait correspondre
        let fakeHash: UInt64 = 0xDEADBEEFCAFEBABE
        let move = await book.selectMove(hash: fakeHash, state: state, legalMoves: legalMoves)
        #expect(move == nil, "Un hash inconnu ne devrait pas retourner de coup")
    }
}
