import Foundation

/// Result of a Stockfish cloud search.
enum CloudAIResult: Sendable {
    /// Successful move lookup.
    case success(Move)
    /// Network error.
    case networkError
    /// API error.
    case apiError
}

/// Stockfish cloud-backed AI.
/// Uses Lichess Cloud Eval first, then stockfish.online as fallback.
actor StockfishCloudAI {

    private let color: PieceColor

    private static let lichessURL = "https://lichess.org/api/cloud-eval"
    private static let stockfishOnlineURL = "https://stockfish.online/api/s/v2.php"

    /// Request timeout.
    private static let requestTimeout: TimeInterval = 5.0

    /// `URLError` codes treated as network failures.
    private static let networkErrorCodes: Set<URLError.Code> = [
        .notConnectedToInternet,
        .networkConnectionLost,
        .timedOut,
        .cannotFindHost,
        .cannotConnectToHost,
        .dnsLookupFailed,
        .dataNotAllowed
    ]

    init(color: PieceColor) {
        self.color = color
    }

    /// Computes the best move via Stockfish cloud services.
    func findBestMoveResult(for board: ChessBoard) async -> CloudAIResult {
        let fen = await board.toFEN()
        let legalMoves = await board.getAllLegalMoves(for: color)
        guard !legalMoves.isEmpty else { return .apiError }

        var sawNetworkError = false

        // 1. Try Lichess Cloud Eval.
        let lichessResult = await fetchFromLichess(fen: fen)
        switch lichessResult {
        case .success(let uci):
            if let move = resolveUCI(uci, from: legalMoves) {
                Logger.debug("StockfishCloud: Lichess hit → \(uci)", subsystem: .game)
                return .success(move)
            }
        case .networkError:
            sawNetworkError = true
        case .noResult:
            break // 404, pas en cache — essayer stockfish.online
        }

        // 2. Fall back to stockfish.online.
        let sfOnlineResult = await fetchFromStockfishOnline(fen: fen)
        switch sfOnlineResult {
        case .success(let uci):
            if let move = resolveUCI(uci, from: legalMoves) {
                Logger.debug("StockfishCloud: stockfish.online hit → \(uci)", subsystem: .game)
                return .success(move)
            }
        case .networkError:
            sawNetworkError = true
        case .noResult:
            break
        }

        // 3. All cloud sources failed.
        if sawNetworkError {
            Logger.warning("StockfishCloud: network error — no internet or timeout", subsystem: .game)
            return .networkError
        } else {
            Logger.warning("StockfishCloud: API error — services unavailable", subsystem: .game)
            return .apiError
        }
    }

    // MARK: - Internal fetch result

    /// Result of a single API call.
    private enum FetchResult {
        case success(String)
        case networkError
        case noResult
    }

    // MARK: - Lichess Cloud Eval

    /// Queries the Lichess cloud evaluation endpoint.
    private func fetchFromLichess(fen: String) async -> FetchResult {
        guard var components = URLComponents(string: Self.lichessURL) else { return .noResult }
        components.queryItems = [
            URLQueryItem(name: "fen", value: fen),
            URLQueryItem(name: "multiPv", value: "1")
        ]
        guard let url = components.url else { return .noResult }

        var request = URLRequest(url: url)
        request.timeoutInterval = Self.requestTimeout

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return .noResult
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let pvs = json["pvs"] as? [[String: Any]],
               let firstPV = pvs.first,
               let moves = firstPV["moves"] as? String,
               let firstMove = moves.split(separator: " ").first {
                return .success(String(firstMove))
            }
            return .noResult
        } catch let error as URLError where Self.networkErrorCodes.contains(error.code) {
            return .networkError
        } catch {
            return .noResult
        }
    }

    // MARK: - stockfish.online

    /// Queries stockfish.online for a real-time analysis.
    private func fetchFromStockfishOnline(fen: String) async -> FetchResult {
        guard var components = URLComponents(string: Self.stockfishOnlineURL) else { return .noResult }
        components.queryItems = [
            URLQueryItem(name: "fen", value: fen),
            URLQueryItem(name: "depth", value: "12")
        ]
        guard let url = components.url else { return .noResult }

        var request = URLRequest(url: url)
        request.timeoutInterval = Self.requestTimeout

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return .noResult
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool, success,
               let bestmoveRaw = json["bestmove"] as? String {
                let parts = bestmoveRaw.split(separator: " ")
                if parts.count >= 2 {
                    return .success(String(parts[1]))
                }
            }
            return .noResult
        } catch let error as URLError where Self.networkErrorCodes.contains(error.code) {
            return .networkError
        } catch {
            return .noResult
        }
    }

    // MARK: - UCI resolution

    /// Converts a UCI move into a legal `Move`.
    private func resolveUCI(_ uci: String, from legalMoves: [Move]) -> Move? {
        guard uci.count >= 4 else { return nil }

        let fromNotation = String(uci.prefix(2))
        let toNotation = String(uci.dropFirst(2).prefix(2))

        guard let fromPos = Position(notation: fromNotation),
              let toPos = Position(notation: toNotation) else {
            return nil
        }

        var promotionType: PieceType?
        if uci.count == 5, let promoChar = uci.last {
            promotionType = pieceTypeFromUCI(promoChar)
        }

        return legalMoves.first { move in
            move.from == fromPos
                && move.to == toPos
                && move.promotionType == promotionType
        }
    }

    /// Converts a UCI promotion character into a `PieceType`.
    private func pieceTypeFromUCI(_ char: Character) -> PieceType? {
        switch char {
        case "q": return .queen
        case "r": return .rook
        case "b": return .bishop
        case "n": return .knight
        default: return nil
        }
    }
}
