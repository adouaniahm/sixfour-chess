//
//  NNUEEvaluator.swift
//  SixFourChess
//
//  CoreML wrapper for a chess NNUE evaluator.
//
//  NNUE (Efficiently Updatable Neural Network):
//    Architecture: 768 → 256 → 32 → 32 → 1
//    Input: 768-dim feature vector (12 planes × 64 squares, binary)
//    Output: centipawn score (positive = white advantage)
//
//  The model is loaded from the app bundle. If it is unavailable, `evaluate()`
//  returns nil and `RAGChessAI` falls back to the heuristic evaluator.
//
//  Key optimizations:
//    - `MLModelConfiguration.computeUnits = .all`
//    - Zobrist cache to avoid reevaluating positions
//    - Preallocated `MLMultiArray`
//    - `dataPointer` writes to avoid boxing
//    - Synchronous prediction on the actor
//

import Foundation
import CoreML

/// Sendable ownership token for Core ML's thread-safe model object.
/// Each actor still owns and reuses its own input buffers and feature provider.
nonisolated final class CoreMLModelHandle: @unchecked Sendable {
    let model: MLModel

    init(model: MLModel) {
        self.model = model
    }
}

// MARK: - NNUEEvaluator

/// Évaluateur de positions d'échecs via un modèle NNUE CoreML.
///
/// Thread-safe via actor isolation. Le modèle est chargé/déchargé à la demande.
/// Retourne nil si aucun modèle n'est chargé (fallback transparent).
@available(iOS 17.0, *)
actor NNUEEvaluator {

    // MARK: - State

    /// Modèle CoreML chargé (nil tant qu'il n'est pas initialisé)
    private var model: MLModel?

    /// Encodeur partagé pour générer les feature vectors
    private let encoder: BoardEncoder

    /// Cache d'évaluations : hash Zobrist → centipawns.
    /// Évite de recalculer le score pour une position déjà vue dans le même arbre.
    /// Vidé à chaque nouvelle recherche via clearCache().
    private var evaluationCache: [UInt64: Int] = [:]

    /// Nom de l'output du modèle CoreML (configuré lors de l'export Python)
    private let outputFeatureName = "evaluation"

    /// MLMultiArray pré-alloué, réutilisé entre les évaluations.
    /// Élimine l'allocation/deallocation de 768×4 bytes à chaque feuille.
    private var reusableInput: MLMultiArray?

    /// Feature provider pré-alloué, réutilisé entre les évaluations.
    private var reusableProvider: MLDictionaryFeatureProvider?

    // MARK: - Initialization

    /// Crée un NNUEEvaluator.
    ///
    /// Le modèle n'est pas chargé à l'init — appeler loadModel(from:) avec l'URL du bundle.
    ///
    /// - Parameter encoder: Encodeur partagé pour la conversion board → features.
    init(encoder: BoardEncoder) {
        self.encoder = encoder
    }

    // MARK: - Model Management

    /// Charge un modèle CoreML compilé (.mlmodelc) depuis une URL locale.
    ///
    /// Configure le modèle pour utiliser tous les compute units disponibles
    /// (CPU + GPU + Neural Engine) pour des performances optimales.
    /// Pré-alloue le MLMultiArray d'entrée pour éviter les allocations à chaud.
    ///
    /// - Parameter url: URL vers le bundle .mlmodelc.
    /// - Throws: Erreur si le modèle est invalide ou non compilé.
    func loadModel(from url: URL) throws {
        let config = MLModelConfiguration()
        // .all = CPU + GPU + Neural Engine → le système choisit le plus rapide
        config.computeUnits = .all
        model = try MLModel(contentsOf: url, configuration: config)

        // Pré-allouer le buffer d'entrée (réutilisé pour chaque évaluation)
        let multiArray = try MLMultiArray(shape: [1, 768], dataType: .float32)
        reusableInput = multiArray
        reusableProvider = try MLDictionaryFeatureProvider(
            dictionary: ["features": multiArray]
        )
    }

    /// Décharge le modèle pour libérer la mémoire.
    ///
    /// Utile quand l'utilisateur quitte le mode IA.
    func unloadModel() {
        model = nil
        reusableInput = nil
        reusableProvider = nil
        evaluationCache.removeAll()
    }

    /// Indique si un modèle est chargé et prêt pour l'inférence.
    var isReady: Bool {
        model != nil
    }

    /// Exposes a Sendable handle for synchronous inference on another actor.
    ///
    /// L'appelant crée ses propres buffers MLMultiArray et cache.
    /// `MLModel.prediction(from:)` est thread-safe (Apple docs),
    /// donc partager le modèle entre actors est sûr.
    ///
    /// - Returns: A handle to the loaded model, or nil when unavailable.
    func borrowModel() -> CoreMLModelHandle? {
        model.map { CoreMLModelHandle(model: $0) }
    }

    /// Vide le cache d'évaluations.
    ///
    /// À appeler au début de chaque nouvelle recherche Negamax
    /// pour éviter une croissance illimitée de la mémoire.
    func clearCache() {
        evaluationCache.removeAll(keepingCapacity: true)
    }

    // MARK: - Evaluation (Fast Path)

    /// Évalue une position avec hash et features pré-calculés.
    ///
    /// Fast path optimisé pour le negamax :
    /// - Pas d'actor hop vers BoardEncoder (hash + features déjà calculés)
    /// - Réutilise le MLMultiArray pré-alloué (0 allocation)
    /// - Remplissage via dataPointer (0 NSNumber boxing)
    /// - Prédiction synchrone (pas d'await, on est sur l'actor)
    ///
    /// - Parameters:
    ///   - hash: Hash Zobrist pré-calculé.
    ///   - features: Feature vector 768-dim pré-calculé.
    ///   - color: Point de vue de l'évaluation.
    ///   - ragBias: Biais centipawns des positions similaires (nil = pas de blend).
    ///   - biasWeight: Poids du biais [0.0, 1.0]. 0 = NNUE pur.
    /// - Returns: Score en centipawns (positif = bon pour `color`), ou nil si modèle absent.
    func evaluate(
        hash: UInt64,
        features: [Float],
        for color: PieceColor,
        ragBias: Int?,
        biasWeight: Double
    ) -> Int? {
        guard let model = model,
              let multiArray = reusableInput,
              let provider = reusableProvider else { return nil }

        // ── Cache lookup ──
        if let cached = evaluationCache[hash] {
            return applyPerspectiveAndBlend(
                rawScore: cached, color: color, ragBias: ragBias, biasWeight: biasWeight
            )
        }

        // ── Remplir le MLMultiArray via dataPointer (0 NSNumber boxing) ──
        let ptr = multiArray.dataPointer.bindMemory(to: Float.self, capacity: 768)
        for i in 0..<768 {
            ptr[i] = features[i]
        }

        // ── Prédiction CoreML synchrone ──
        guard let prediction = try? model.prediction(from: provider) else {
            return nil
        }

        // Extraire le score : le modèle produit un MLMultiArray [1,1] en pawns.
        guard let outputValue = prediction.featureValue(for: outputFeatureName),
              let outputArray = outputValue.multiArrayValue else {
            return nil
        }

        // Le modèle sort en "pawns" (divisé par 100 à l'entraînement),
        // on reconvertit en centipawns
        let rawScore = Int(outputArray[0].doubleValue * 100.0)

        // Stocker dans le cache (score brut, perspective blanche)
        evaluationCache[hash] = rawScore

        return applyPerspectiveAndBlend(
            rawScore: rawScore, color: color, ragBias: ragBias, biasWeight: biasWeight
        )
    }

    // MARK: - Evaluation (Legacy Path)

    /// Évalue une position avec le modèle NNUE, optionnellement blendée avec un biais RAG.
    ///
    /// Version compatible avec l'ancienne API. Calcule hash et features en interne.
    /// Préférer `evaluate(hash:features:for:ragBias:biasWeight:)` depuis le negamax
    /// pour éviter les appels redondants à l'encodeur.
    func evaluate(
        state: ChessState,
        for color: PieceColor,
        ragBias: Int?,
        biasWeight: Double
    ) async -> Int? {
        guard model != nil else { return nil }

        // BoardEncoder est nonisolated → pas d'await
        let hash = encoder.zobristHash(for: state)
        let features = encoder.featureVector(for: state)

        return evaluate(
            hash: hash,
            features: features,
            for: color,
            ragBias: ragBias,
            biasWeight: biasWeight
        )
    }

    // MARK: - Helpers

    /// Ajuste un score white-relative pour le point de vue de `color`,
    /// puis blend avec le biais RAG si fourni.
    private func applyPerspectiveAndBlend(
        rawScore: Int,
        color: PieceColor,
        ragBias: Int?,
        biasWeight: Double
    ) -> Int {
        var score = color == .white ? rawScore : -rawScore

        if let bias = ragBias, biasWeight > 0 {
            let adjustedBias = color == .white ? bias : -bias
            score = Int(
                Double(score) * (1.0 - biasWeight) + Double(adjustedBias) * biasWeight
            )
        }

        return score
    }
}
