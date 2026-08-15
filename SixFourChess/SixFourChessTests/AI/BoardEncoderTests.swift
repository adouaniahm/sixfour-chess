import Testing
import Foundation
@testable import SixFour

@MainActor
@Suite struct BoardEncoderTests {

    // MARK: - Zobrist Hash

    /// Le hash Zobrist de la position initiale DOIT correspondre à la valeur
    /// officielle de la spécification Polyglot : 0x463B96181691FC9C.
    /// C'est le test de conformité le plus critique.
    @Test func startingPositionZobristHash() throws {
        let board = ChessBoard()
        let encoder = BoardEncoder()
        let hash = encoder.zobristHash(for: board.state)
        #expect(hash == 0x463B96181691FC9C)
    }

    /// Après 1.e4, le hash doit changer (propriété fondamentale du Zobrist).
    @Test func hashChangesAfterMove() throws {
        let board = ChessBoard()
        let encoder = BoardEncoder()

        let hashBefore = encoder.zobristHash(for: board.state)

        // Jouer e2-e4
        let pawn = board.piece(at: pos("e2"))!
        let move = Move(from: pos("e2"), to: pos("e4"), piece: pawn)
        board.makeMove(move)

        let hashAfter = encoder.zobristHash(for: board.state)
        #expect(hashBefore != hashAfter)
    }

    /// Deux positions identiques doivent avoir le même hash.
    @Test func identicalPositionsSameHash() throws {
        let board1 = ChessBoard()
        let board2 = ChessBoard()
        let encoder = BoardEncoder()

        let hash1 = encoder.zobristHash(for: board1.state)
        let hash2 = encoder.zobristHash(for: board2.state)
        #expect(hash1 == hash2)
    }

    /// Le hash de la même position via FEN doit correspondre.
    @Test func fenLoadedPositionSameHash() throws {
        let board1 = ChessBoard()
        let board2 = try ChessBoard(fen: TestFEN.starting)
        let encoder = BoardEncoder()

        let hash1 = encoder.zobristHash(for: board1.state)
        let hash2 = encoder.zobristHash(for: board2.state)
        #expect(hash1 == hash2)
    }

    /// Les droits de roque affectent le hash.
    @Test func castlingRightsAffectHash() throws {
        let encoder = BoardEncoder()

        // Tous les droits de roque
        let boardFull = try ChessBoard(fen: TestFEN.castlingBothSides)
        let hashFull = encoder.zobristHash(for: boardFull.state)

        // Pas de roque blanc
        let boardNoWhite = try ChessBoard(fen: TestFEN.castlingNone)
        let hashNoWhite = encoder.zobristHash(for: boardNoWhite.state)

        #expect(hashFull != hashNoWhite)
    }

    // MARK: - Feature Vector

    /// Le feature vector de la position initiale doit avoir 768 éléments.
    @Test func featureVectorSize() {
        let board = ChessBoard()
        let encoder = BoardEncoder()
        let features = encoder.featureVector(for: board.state)
        #expect(features.count == 768)
    }

    /// Le feature vector de la position initiale doit avoir exactement 32 pièces (32 bits à 1).
    @Test func featureVectorStartingPieceCount() {
        let board = ChessBoard()
        let encoder = BoardEncoder()
        let features = encoder.featureVector(for: board.state)

        let activeBits = features.filter { $0 > 0.5 }.count
        #expect(activeBits == 32)
    }

    /// Toutes les valeurs du feature vector sont soit 0.0 soit 1.0.
    @Test func featureVectorBinaryValues() {
        let board = ChessBoard()
        let encoder = BoardEncoder()
        let features = encoder.featureVector(for: board.state)

        for value in features {
            #expect(value == 0.0 || value == 1.0)
        }
    }

    // MARK: - Compact Embedding

    /// L'embedding compact doit faire 96 bytes (768 bits / 8).
    @Test func compactEmbeddingSize() {
        let board = ChessBoard()
        let encoder = BoardEncoder()
        let embedding = encoder.compactEmbedding(for: board.state)
        #expect(embedding.count == 96)
    }

    /// L'embedding compact doit être cohérent avec le feature vector.
    @Test func compactEmbeddingConsistency() {
        let board = ChessBoard()
        let encoder = BoardEncoder()
        let features = encoder.featureVector(for: board.state)
        let embedding = encoder.compactEmbedding(for: board.state)

        // Vérifier que chaque bit dans l'embedding correspond au feature vector
        for i in 0..<768 {
            let byteIndex = i / 8
            let bitIndex = i % 8
            let bit = (embedding[byteIndex] >> bitIndex) & 1
            let expected: UInt8 = features[i] > 0.5 ? 1 : 0
            #expect(bit == expected, "Mismatch at index \(i)")
        }
    }
}
