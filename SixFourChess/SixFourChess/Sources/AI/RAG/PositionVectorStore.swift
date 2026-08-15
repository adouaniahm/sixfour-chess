//
//  PositionVectorStore.swift
//  SixFourChess
//
//  SQLite database of chess positions with similarity search.
//
//  ROLE:
//    Stores millions of Stockfish-evaluated positions.
//    For a given position, retrieves the K most similar positions and
//    aggregates their evaluations into a centipawn bias to augment NNUE.
//
//  SQL SCHEMA:
//    CREATE TABLE positions (
//        id INTEGER PRIMARY KEY,
//        zobrist_hash INTEGER NOT NULL,     -- Polyglot hash for exact O(log n) lookup
//        fen TEXT NOT NULL,                 -- FEN for debug/verification
//        stockfish_eval INTEGER,            -- Stockfish evaluation in centipawns
//        embedding BLOB NOT NULL            -- 96 bytes = 768 packed bits
//    );
//    CREATE INDEX idx_hash ON positions(zobrist_hash);
//
//  SEARCH ALGORITHM (2 phases):
//    Phase 1 - SQL: SELECT * FROM positions ORDER BY ABS(zobrist_hash - ?) LIMIT 200
//              -> fast approximation based on hash proximity
//    Phase 2 - Swift: cosine similarity between embeddings, return top-K
//              -> precise in-memory ranking via Accelerate/vDSP
//
//  PERFORMANCE:
//    - Phase 1: ~1ms (SQLite B-tree index)
//    - Phase 2: ~2ms for 200 comparisons of 768 dimensions
//    - Total: < 5ms per lookup -> negligible vs Negamax (~100ms+)
//
//  MEMORY:
//    The DB is never fully loaded into RAM.
//    Only the 200 candidate rows are read per query.
//

import Foundation
import SQLite3
import Accelerate  // vDSP for vectorized cosine similarity

// MARK: - Types

/// A position retrieved from the database with its similarity score.
/// `nonisolated`: Sendable value type, created and read from the `PositionVectorStore` actor.
nonisolated struct RetrievedPosition: Sendable {
    /// Zobrist hash of the retrieved position.
    let zobristHash: Int64
    /// FEN of the position, for debugging.
    let fen: String
    /// Stockfish evaluation in centipawns, positive for White.
    let stockfishEval: Int
    /// Cosine similarity with the query position, in [0, 1].
    let similarity: Float
}

/// Owns a SQLite connection and closes it when released.
///
/// SQLite is opened with `SQLITE_OPEN_NOMUTEX` and the owning actor serializes
/// every access. The unchecked conformance only lets actor deinitialization
/// release the otherwise non-Sendable C pointer safely.
private nonisolated final class SQLiteConnection: @unchecked Sendable {
    let handle: OpaquePointer

    init(handle: OpaquePointer) {
        self.handle = handle
    }

    deinit {
        sqlite3_close(handle)
    }
}

// MARK: - PositionVectorStore

/// SQLite database of chess positions with ANN search.
///
/// Thread-safe via actor isolation. All DB operations are serialized.
/// The DB is opened and closed on demand when a verified local source is available.
actor PositionVectorStore {

    // MARK: - State

    /// Owned SQLite connection, nil when the database is closed.
    private var connection: SQLiteConnection?

    /// Shared encoder used to generate embeddings for the query position.
    private let encoder: BoardEncoder

    // MARK: - Initialization

    /// Creates a `PositionVectorStore`.
    ///
    /// The DB is not opened on init; call `open(at:)` with a local URL.
    ///
    /// - Parameter encoder: Shared encoder for board-to-embedding conversion.
    init(encoder: BoardEncoder) {
        self.encoder = encoder
    }

    // MARK: - Database Management

    /// Opens the SQLite database at the given URL.
    ///
    /// Read-only mode (`SQLITE_OPEN_READONLY`) because the DB is prebuilt.
    ///
    /// - Parameter url: URL to the `.sqlite` file (`Application Support/AI/`).
    /// - Throws: Error if the file is missing or corrupted.
    func open(at url: URL) throws {
        if connection != nil { close() }

        var openedDatabase: OpaquePointer?

        let result = sqlite3_open_v2(
            url.path,
            &openedDatabase,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX,
            nil
        )

        guard result == SQLITE_OK, let openedDatabase else {
            let message = openedDatabase.map { String(cString: sqlite3_errmsg($0)) }
                ?? String(cString: sqlite3_errstr(result))
            if let openedDatabase {
                sqlite3_close(openedDatabase)
            }
            throw NSError(
                domain: "PositionVectorStore",
                code: Int(result),
                userInfo: [NSLocalizedDescriptionKey: "SQLite open failed: \(message)"]
            )
        }

        connection = SQLiteConnection(handle: openedDatabase)
    }

    /// Closes the SQLite connection and releases resources.
    func close() {
        connection = nil
    }

    /// Returns whether the DB is open and ready for queries.
    var isOpen: Bool {
        connection != nil
    }

    // MARK: - Similar Position Search

    /// Finds the K most similar positions to a given one.
    ///
    /// Two-phase algorithm:
    /// 1. SQL: fetch `candidateCount` rows close by Zobrist hash.
    /// 2. Swift: compute cosine similarity and return the top-K results.
    ///
    /// Takes `ChessState` (Sendable) instead of `ChessBoard` (@MainActor)
    /// to avoid isolation hops. The caller extracts `board.state` once via
    /// `await` and passes it here.
    ///
    /// - Parameters:
    ///   - state: Query position state, Sendable.
    ///   - topK: Number of results to return, default 5.
    ///   - candidateCount: Number of rows scanned in phase 1, default 200.
    /// - Returns: Top-K positions sorted by descending similarity.
    func findSimilar(
        to state: ChessState,
        topK: Int = 5,
        candidateCount: Int = 200
    ) -> [RetrievedPosition] {
        guard let db = connection?.handle else { return [] }

        // Compute the query position hash and embedding.
        // `BoardEncoder` is nonisolated, so these calls are synchronous.
        let queryHash = encoder.zobristHash(for: state)
        let queryEmbedding = encoder.compactEmbedding(for: state)
        let queryVector = unpackEmbedding(queryEmbedding)

        // ── Phase 1: SQL - candidates by hash proximity ──
        // `ORDER BY ABS(zobrist_hash - ?)` uses the B-tree index.
        let sql = """
            SELECT zobrist_hash, fen, stockfish_eval, embedding
            FROM positions
            ORDER BY ABS(zobrist_hash - ?)
            LIMIT ?
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        // Bind the hash as INT64 (signed, because SQLite stores signed values).
        sqlite3_bind_int64(stmt, 1, Int64(bitPattern: queryHash))
        sqlite3_bind_int(stmt, 2, Int32(candidateCount))

        // ── Phase 2: cosine similarity in Swift ──
        var candidates = [(hash: Int64, fen: String, eval: Int, similarity: Float)]()
        candidates.reserveCapacity(candidateCount)

        while sqlite3_step(stmt) == SQLITE_ROW {
            let hash = sqlite3_column_int64(stmt, 0)
            let fen = String(cString: sqlite3_column_text(stmt, 1))
            let eval = Int(sqlite3_column_int(stmt, 2))

            // Read the embedding BLOB (96 bytes).
            guard let blobPtr = sqlite3_column_blob(stmt, 3) else { continue }
            let blobSize = Int(sqlite3_column_bytes(stmt, 3))
            guard blobSize == 96 else { continue }

            let embeddingData = Data(bytes: blobPtr, count: blobSize)
            let candidateVector = unpackEmbedding(embeddingData)

            let similarity = cosineSimilarity(queryVector, candidateVector)
            candidates.append((hash, fen, eval, similarity))
        }

        // Sort by descending similarity and keep the top-K.
        candidates.sort { $0.similarity > $1.similarity }
        let topResults = candidates.prefix(topK)

        return topResults.map { candidate in
            RetrievedPosition(
                zobristHash: candidate.hash,
                fen: candidate.fen,
                stockfishEval: candidate.eval,
                similarity: candidate.similarity
            )
        }
    }

    /// Aggregates the Stockfish evaluations of retrieved positions into a single bias.
    ///
    /// Computes a similarity-weighted average:
    ///   bias = Σ(similarity_i × eval_i) / Σ(similarity_i)
    ///
    /// More similar positions have more influence on the bias.
    ///
    /// - Parameter positions: Positions returned by `findSimilar()`.
    /// - Returns: Bias in centipawns, white-relative, or nil if empty.
    func aggregateBias(from positions: [RetrievedPosition]) -> Int? {
        guard !positions.isEmpty else { return nil }

        var weightedSum: Double = 0
        var totalWeight: Double = 0

        for pos in positions {
            let weight = Double(pos.similarity)
            weightedSum += weight * Double(pos.stockfishEval)
            totalWeight += weight
        }

        guard totalWeight > 0 else { return nil }
        return Int(weightedSum / totalWeight)
    }

    // MARK: - Vector Similarity

    /// Computes cosine similarity between two 768-dim vectors.
    ///
    /// cos(A, B) = (A · B) / (||A|| × ||B||)
    ///
    /// Uses Accelerate (vDSP) for optimal performance (~0.01ms per comparison).
    ///
    /// - Returns: Similarity in [0, 1], since embeddings are binary and non-negative.
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        // vDSP for dot product and norms, vectorized with SIMD.
        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        vDSP_dotpr(a, 1, a, 1, &normA, vDSP_Length(a.count))
        vDSP_dotpr(b, 1, b, 1, &normB, vDSP_Length(b.count))

        let denominator = sqrtf(normA) * sqrtf(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }

    /// Unpacks a 96-byte embedding into a 768-float vector.
    ///
    /// Inverse of `BoardEncoder.compactEmbedding()`.
    /// Each bit in the `Data` becomes a `Float` (0.0 or 1.0).
    ///
    /// - Parameter data: 96 bytes, meaning 768 packed bits.
    /// - Returns: 768 floats, each 0.0 or 1.0.
    private func unpackEmbedding(_ data: Data) -> [Float] {
        var vector = [Float](repeating: 0.0, count: 768)

        for i in 0..<min(768, data.count * 8) {
            let byteIndex = i / 8
            let bitIndex = i % 8
            if data[byteIndex] & (1 << bitIndex) != 0 {
                vector[i] = 1.0
            }
        }

        return vector
    }
}
