//
//  OpeningBook.swift
//  SixFourChess
//
//  Parses and queries a Polyglot opening book (`.bin`).
//
//  POLYGLOT FORMAT:
//    Binary, big-endian file made of 16-byte entries:
//    ┌──────────┬────────┬────────┬────────┐
//    │ key (8B) │move(2B)│weight  │ learn  │
//    │ uint64   │uint16  │uint16  │uint32  │
//    └──────────┴────────┴────────┴────────┘
//
//    - key    : Polyglot Zobrist hash of the position
//    - move   : compact move encoding (see decoding below)
//    - weight : relative weight (move frequency/popularity)
//    - learn  : learning field (not used for reads)
//
//  MOVE ENCODING (16 bits):
//    bits [0..2]   : destination file (0=a)
//    bits [3..5]   : destination rank (0=rank 1)
//    bits [6..8]   : source file
//    bits [9..11]  : source rank
//    bits [12..14] : promotion type (0=none, 1=knight, 2=bishop, 3=rook, 4=queen)
//
//  LOOKUP:
//    The file is sorted by ascending key -> binary search O(log n).
//    For a given position, we find all entries with the same hash
//    and select a move proportionally to the weight.
//
//  USAGE:
//    1. Bundler opening_book.bin dans Resources (~5 Mo)
//    2. let book = try await OpeningBook(url: bookURL)
//    3. let move = await book.selectMove(hash: zobristHash, on: board)
//

import Foundation

    // MARK: - Types

/// Errors specific to loading and querying the opening book.
/// `nonisolated`: Sendable type used from non-MainActor actors.
nonisolated enum OpeningBookError: Error, LocalizedError {
    case fileNotFound(String)
    case invalidFormat(String)
    case readError(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path): return "Opening book not found: \(path)"
        case .invalidFormat(let reason): return "Invalid book format: \(reason)"
        case .readError(let reason): return "Read error: \(reason)"
        }
    }
}

/// A Polyglot opening-book entry.
///
/// Represents a recommended move for a given position,
/// with a weight indicating its relative popularity.
/// `nonisolated`: Sendable value type, handled by the `OpeningBook` actor.
nonisolated struct PolyglotEntry: Sendable {
    /// Zobrist hash of the position, for verification.
    let key: UInt64
    /// Source square of the move.
    let from: Position
    /// Destination square of the move.
    let to: Position
    /// Promotion type, or nil if there is no promotion.
    let promotion: PieceType?
    /// Relative weight: higher means the move is more played/recommended.
    let weight: UInt16
}

// MARK: - OpeningBook

/// Parses and queries a Polyglot opening book (`.bin`).
///
/// The whole file is loaded into memory on init (~5 MB).
/// Entries are sorted by key to allow fast binary search.
/// Thread-safe via actor isolation.
actor OpeningBook {

    /// Entries sorted by key for binary search.
    private let entries: [PolyglotEntry]

    // MARK: - Initialization

    /// Loads an opening book from a Polyglot `.bin` file.
    ///
    /// - Parameter url: URL to the `.bin` file, for example `Bundle.main.url(forResource:)`.
    /// - Throws: `OpeningBookError` if the file is missing or corrupted.
    init(url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw OpeningBookError.fileNotFound(url.path)
        }

        let data = try Data(contentsOf: url)

        // Each entry is 16 bytes. The file size must be a multiple of 16.
        guard data.count % 16 == 0 else {
            throw OpeningBookError.invalidFormat(
                "File size \(data.count) is not a multiple of 16"
            )
        }

        let entryCount = data.count / 16
        var parsed = [PolyglotEntry]()
        parsed.reserveCapacity(entryCount)

        // Parse each 16-byte block, big-endian.
        for i in 0..<entryCount {
            let offset = i * 16

            // Read fields in big-endian order.
            let key = data.readUInt64BE(at: offset)
            let rawMove = data.readUInt16BE(at: offset + 8)
            let weight = data.readUInt16BE(at: offset + 10)
            // learn (offset+12, 4 bytes): ignored.

            // Decode the move, using the format described in the header.
            let toFile   = Int(rawMove & 0x7)         // bits 0-2
            let toRank   = Int((rawMove >> 3) & 0x7)   // bits 3-5
            let fromFile = Int((rawMove >> 6) & 0x7)   // bits 6-8
            let fromRank = Int((rawMove >> 9) & 0x7)   // bits 9-11
            let promoBits = Int((rawMove >> 12) & 0x7)  // bits 12-14

            // Convert Polyglot coordinates to app coordinates.
            // Polyglot: rank 0 = rank 1, file 0 = file a
            // App:      row 0 = rank 8, col 0 = file a
            let fromPos = Position(row: 7 - fromRank, col: fromFile)
            let toPos   = Position(row: 7 - toRank, col: toFile)

            // Decode promotion: 0=none, 1=knight, 2=bishop, 3=rook, 4=queen
            let promotion: PieceType? = {
                switch promoBits {
                case 1: return .knight
                case 2: return .bishop
                case 3: return .rook
                case 4: return .queen
                default: return nil
                }
            }()

            parsed.append(PolyglotEntry(
                key: key,
                from: fromPos,
                to: toPos,
                promotion: promotion,
                weight: weight
            ))
        }

        // Sort by key (a valid `.bin` should already be sorted, but we enforce it).
        self.entries = parsed.sorted { $0.key < $1.key }
    }

    // MARK: - Lookup

    /// Finds all entries matching a Zobrist hash.
    ///
    /// Uses binary search to find the first entry,
    /// then linearly scans adjacent entries with the same key.
    ///
    /// - Parameter hash: Polyglot Zobrist hash of the current position.
    /// - Returns: Entries sorted by descending weight. Empty if the position is not in the book.
    func lookup(hash: UInt64) -> [PolyglotEntry] {
        // Binary search: find an index with `key == hash`.
        guard let firstIndex = binarySearch(for: hash) else {
            return []
        }

        // Scan left to find the start of the group.
        var start = firstIndex
        while start > 0 && entries[start - 1].key == hash {
            start -= 1
        }

        // Scan right to collect all entries in the group.
        var results = [PolyglotEntry]()
        var idx = start
        while idx < entries.count && entries[idx].key == hash {
            results.append(entries[idx])
            idx += 1
        }

        // Sort by descending weight, best move first.
        return results.sorted { $0.weight > $1.weight }
    }

    /// Selects a move from the book using weighted sampling.
    ///
    /// Moves with a higher weight are more likely to be chosen.
    /// This adds variety to openings while still favoring main lines.
    ///
    /// Takes `ChessState` (Sendable) instead of `ChessBoard` (@MainActor) to
    /// avoid actor hops in the selection loop.
    ///
    /// - Parameters:
    ///   - hash: Zobrist hash of the position.
    ///   - state: Current board state, Sendable.
    ///   - legalMoves: Precomputed legal moves, used to validate the book move.
    /// - Returns: A valid `Move`, or nil if the position is not in the book.
    func selectMove(hash: UInt64, state: ChessState, legalMoves: [Move]) -> Move? {
        let bookEntries = lookup(hash: hash)
        guard !bookEntries.isEmpty else { return nil }

        // Weighted sampling: probability proportional to weight.
        let totalWeight = bookEntries.reduce(0) { $0 + Int($1.weight) }
        guard totalWeight > 0 else { return nil }

        var roll = Int.random(in: 0..<totalWeight)
        for entry in bookEntries {
            roll -= Int(entry.weight)
            if roll < 0 {
                return toMove(entry, state: state, legalMoves: legalMoves)
            }
        }

        // Fallback: return the first entry, which has the highest weight.
        return toMove(bookEntries[0], state: state, legalMoves: legalMoves)
    }

    /// Selects the best move, the one with the highest weight, without randomness.
    ///
    /// Used for higher difficulty levels (hard/expert)
    /// where we want the theoretically strongest move.
    ///
    /// - Parameters:
    ///   - hash: Hash Zobrist de la position.
    ///   - state: Current board state, Sendable.
    ///   - legalMoves: Precomputed legal moves.
    /// - Returns: The move with the highest weight, or nil.
    func bestMove(hash: UInt64, state: ChessState, legalMoves: [Move]) -> Move? {
        let bookEntries = lookup(hash: hash)
        guard let best = bookEntries.first else { return nil }
        return toMove(best, state: state, legalMoves: legalMoves)
    }

    /// Converts a Polyglot entry into an app `Move`.
    ///
    /// Utilise `ChessState` (Sendable) au lieu de `ChessBoard` (@MainActor)
    /// to avoid isolation hops. Pieces are read directly
    /// from `state.board[][]` and flags from `state` properties.
    ///
    /// - Parameters:
    ///   - entry: Polyglot entry to convert.
    ///   - state: Board state used to extract pieces and flags.
    ///   - legalMoves: Legal moves used to validate that the book move is playable.
    /// - Returns: A `Move` compatible with the engine, or nil if illegal.
    func toMove(_ entry: PolyglotEntry, state: ChessState, legalMoves: [Move]) -> Move? {
        // Read directly from `state.board`, so no await is needed.
        guard let piece = state.board[entry.from.row][entry.from.col] else { return nil }

        // Verify that the piece belongs to the current player.
        guard piece.color == state.currentPlayer else { return nil }

        let capturedPiece = state.board[entry.to.row][entry.to.col]

        // En passant detection: pawn captures diagonally on an empty square.
        let isEnPassant = piece.type == .pawn
            && entry.from.col != entry.to.col
            && capturedPiece == nil

        // Castling detection: the king moves two squares.
        let isCastling = piece.type == .king
            && abs(entry.to.col - entry.from.col) == 2

        // En passant capture piece (on the source pawn rank).
        let actualCapture: Piece?
        if isEnPassant {
            actualCapture = state.board[entry.from.row][entry.to.col]
        } else {
            actualCapture = capturedPiece
        }

        // Construire le Move avec le contexte depuis ChessState
        let move = Move(
            from: entry.from,
            to: entry.to,
            piece: piece,
            capturedPiece: actualCapture,
            isEnPassant: isEnPassant,
            isCastling: isCastling,
            promotionType: entry.promotion,
            previousEnPassantTarget: state.enPassantTarget,
            previousHalfMoveClock: state.halfMoveClock,
            previousWhiteKingMoved: state.isWhiteKingMoved,
            previousBlackKingMoved: state.isBlackKingMoved,
            previousWhiteRookLeftMoved: state.isWhiteRookLeftMoved,
            previousWhiteRookRightMoved: state.isWhiteRookRightMoved,
            previousBlackRookLeftMoved: state.isBlackRookLeftMoved,
            previousBlackRookRightMoved: state.isBlackRookRightMoved
        )

        // Verify that the move is legal. The book may contain illegal moves
        // in some positions because of hash collisions.
        let isLegal = legalMoves.contains { legal in
            legal.from == move.from
            && legal.to == move.to
            && legal.promotionType == move.promotionType
        }

        return isLegal ? move : nil
    }

    // MARK: - Binary Search

    /// Recherche binaire dans le tableau trié par key.
    /// - Returns: Un index quelconque avec key == target, ou nil.
    private func binarySearch(for target: UInt64) -> Int? {
        var low = 0
        var high = entries.count - 1

        while low <= high {
            let mid = low + (high - low) / 2
            let midKey = entries[mid].key

            if midKey == target {
                return mid
            } else if midKey < target {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return nil
    }
}

// MARK: - Data Extensions for Big-Endian Reads

/// `nonisolated` car Data est un type valeur Sendable, et ces fonctions
/// sont des calculs purs sans effet de bord. Elles doivent être accessibles
/// depuis l'actor OpeningBook (non-MainActor).
private extension Data {
    nonisolated func readUInt64BE(at offset: Int) -> UInt64 {
        var value: UInt64 = 0
        for i in 0..<8 {
            value = (value << 8) | UInt64(self[offset + i])
        }
        return value
    }

    nonisolated func readUInt16BE(at offset: Int) -> UInt16 {
        return (UInt16(self[offset]) << 8) | UInt16(self[offset + 1])
    }
}
