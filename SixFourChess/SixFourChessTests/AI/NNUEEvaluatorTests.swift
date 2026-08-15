import Testing
import Foundation
@testable import SixFour

@MainActor
@Suite struct NNUEEvaluatorTests {

    /// Un NNUEEvaluator sans modèle chargé doit retourner nil (pas de crash).
    @Test func evaluateWithoutModelReturnsNil() async {
        if #available(iOS 17.0, *) {
            let encoder = BoardEncoder()
            let evaluator = NNUEEvaluator(encoder: encoder)
            let board = ChessBoard()

            let score = await evaluator.evaluate(
                state: board.state,
                for: .white,
                ragBias: nil,
                biasWeight: 0.0
            )
            #expect(score == nil, "Sans modèle chargé, evaluate() doit retourner nil")
        }
    }

    /// isReady doit être false quand aucun modèle n'est chargé.
    @Test func isReadyFalseWithoutModel() async {
        if #available(iOS 17.0, *) {
            let encoder = BoardEncoder()
            let evaluator = NNUEEvaluator(encoder: encoder)
            let ready = await evaluator.isReady
            #expect(!ready, "isReady doit être false sans modèle")
        }
    }

    /// clearCache ne doit pas crasher (même si le cache est vide).
    @Test func clearCacheDoesNotCrash() async {
        if #available(iOS 17.0, *) {
            let encoder = BoardEncoder()
            let evaluator = NNUEEvaluator(encoder: encoder)
            await evaluator.clearCache()
            // Pas de crash = succès
        }
    }

    /// unloadModel ne doit pas crasher (même si aucun modèle n'est chargé).
    @Test func unloadModelDoesNotCrash() async {
        if #available(iOS 17.0, *) {
            let encoder = BoardEncoder()
            let evaluator = NNUEEvaluator(encoder: encoder)
            await evaluator.unloadModel()
            let ready = await evaluator.isReady
            #expect(!ready, "isReady doit rester false après unloadModel")
        }
    }

    /// Charger un modèle depuis une URL invalide doit throw (pas de crash silencieux).
    @Test func loadInvalidModelThrows() async {
        if #available(iOS 17.0, *) {
            let encoder = BoardEncoder()
            let evaluator = NNUEEvaluator(encoder: encoder)
            let fakeURL = URL(fileURLWithPath: "/nonexistent/model.mlmodelc")

            do {
                try await evaluator.loadModel(from: fakeURL)
                Issue.record("loadModel avec URL invalide devrait throw")
            } catch {
                // Erreur attendue → OK
            }
        }
    }

    /// evaluate avec ragBias non-nil ne doit pas crasher (même sans modèle).
    @Test func evaluateWithRagBiasAndNoModel() async {
        if #available(iOS 17.0, *) {
            let encoder = BoardEncoder()
            let evaluator = NNUEEvaluator(encoder: encoder)
            let board = ChessBoard()

            let score = await evaluator.evaluate(
                state: board.state,
                for: .black,
                ragBias: 150,
                biasWeight: 0.15
            )
            #expect(score == nil, "Sans modèle, evaluate retourne nil même avec ragBias")
        }
    }

    // MARK: - Tests avec modèle bundlé

    /// Le modèle bundlé doit se charger sans erreur.
    @Test func loadBundledModel() async throws {
        if #available(iOS 17.0, *) {
            guard let modelURL = Bundle.main.url(forResource: "nnue", withExtension: "mlmodelc") else {
                Issue.record("nnue.mlmodelc introuvable dans le bundle")
                return
            }

            let encoder = BoardEncoder()
            let evaluator = NNUEEvaluator(encoder: encoder)
            try await evaluator.loadModel(from: modelURL)
            let ready = await evaluator.isReady
            #expect(ready, "isReady doit être true après loadModel")
        }
    }

    /// Le modèle chargé doit retourner un score non-nil pour la position initiale.
    @Test func evaluateStartingPositionWithModel() async throws {
        if #available(iOS 17.0, *) {
            guard let modelURL = Bundle.main.url(forResource: "nnue", withExtension: "mlmodelc") else {
                Issue.record("nnue.mlmodelc introuvable dans le bundle")
                return
            }

            let encoder = BoardEncoder()
            let evaluator = NNUEEvaluator(encoder: encoder)
            try await evaluator.loadModel(from: modelURL)

            let board = ChessBoard()
            let score = await evaluator.evaluate(
                state: board.state,
                for: .white,
                ragBias: nil,
                biasWeight: 0.0
            )
            #expect(score != nil, "Avec modèle, evaluate doit retourner un score")

            // La position initiale est ~égale, le score devrait être dans [-100, 100] cp
            if let score = score {
                #expect(abs(score) < 100,
                    "Position initiale devrait être quasi-égale (score=\(score) cp)")
            }
        }
    }

    /// L'évaluation doit distinguer un avantage matériel net.
    @Test func evaluateDetectsMaterialAdvantage() async throws {
        if #available(iOS 17.0, *) {
            guard let modelURL = Bundle.main.url(forResource: "nnue", withExtension: "mlmodelc") else {
                Issue.record("nnue.mlmodelc introuvable dans le bundle")
                return
            }

            let encoder = BoardEncoder()
            let evaluator = NNUEEvaluator(encoder: encoder)
            try await evaluator.loadModel(from: modelURL)

            // Position avec dame blanche manquante → avantage noir net
            let board = try ChessBoard(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNB1KBNR w KQkq - 0 1")

            let whiteScore = await evaluator.evaluate(
                state: board.state,
                for: .white,
                ragBias: nil,
                biasWeight: 0.0
            )
            #expect(whiteScore != nil, "Doit retourner un score")

            // Sans dame, score blanc devrait être très négatif (< -200 cp)
            if let whiteScore = whiteScore {
                #expect(whiteScore < -200,
                    "Sans dame blanche, score blanc devrait être très négatif (score=\(whiteScore) cp)")
            }
        }
    }

    /// Le cache doit fonctionner (même hash → même score sans recalcul).
    @Test func evaluationCacheWorks() async throws {
        if #available(iOS 17.0, *) {
            guard let modelURL = Bundle.main.url(forResource: "nnue", withExtension: "mlmodelc") else {
                Issue.record("nnue.mlmodelc introuvable dans le bundle")
                return
            }

            let encoder = BoardEncoder()
            let evaluator = NNUEEvaluator(encoder: encoder)
            try await evaluator.loadModel(from: modelURL)

            let board = ChessBoard()
            let score1 = await evaluator.evaluate(
                state: board.state,
                for: .white,
                ragBias: nil,
                biasWeight: 0.0
            )
            let score2 = await evaluator.evaluate(
                state: board.state,
                for: .white,
                ragBias: nil,
                biasWeight: 0.0
            )
            #expect(score1 == score2, "Le cache doit retourner le même score")
        }
    }
}
