import Foundation
#if os(iOS)
import UIKit
#endif

/// Service centralisé pour les annonces VoiceOver
/// Utilisé par le Middleware Redux pour annoncer les événements de jeu
class AccessibilityService {
    static let shared = AccessibilityService()

    private init() {}

    // MARK: - Annonce générique

    /// Annonce un message arbitraire via VoiceOver
    func announce(message: String) {
        #if os(iOS)
        print("🎯 VoiceOver: \(message)")
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }

    // MARK: - Annonces de sélection

    /// Annonce les coups disponibles après sélection d'une pièce
    func announceAvailableMoves(piece: String, from: String, moves: [String]) {
        #if os(iOS)
        let message: String
        if moves.isEmpty {
            message = "a11y.announce.noMoves".localized(with: piece)
        } else if moves.count == 1 {
            message = "a11y.announce.oneMove".localized(with: piece, moves[0])
        } else {
            let destinations = moves.joined(separator: ", ")
            message = "a11y.announce.multipleMoves".localized(with: piece, String(moves.count), destinations)
        }

        print("🎯 VoiceOver: \(message)")
        
        // Délai pour laisser VoiceOver finir l'annonce du label de la case
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        #endif
    }

    // MARK: - Annonces de coups simples (pour GameViewer)

    /// Annonce un coup joué (version simple pour visualisation de parties)
    func announceGenericMove(colorName: String, piece: String, to: String) {
        #if os(iOS)
        let message = "a11y.announce.genericMove".localized(with: colorName, piece, to)
        print("🎯 VoiceOver coup: \(message)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        #endif
    }

    // MARK: - Annonces de coups complètes

    /// Annonce complète d'un coup (Joueur vs Joueur) : coup + échec éventuel + tour
    func announceGenericMoveComplete(colorName: String, piece: String, to: String, checkInfo: (pieces: [Piece], isCheck: Bool)) {
        #if os(iOS)
        var parts: [String] = []

        // 1. Le coup
        let moveMessage = "a11y.announce.genericMove".localized(with: colorName, piece, to)
        parts.append(moveMessage)

        // 2. L'échec éventuel
        if checkInfo.isCheck {
            let checkMessage = buildCheckMessage(threateningPieces: checkInfo.pieces)
            parts.append(checkMessage)
        }

        // 3. Le tour suivant
        let nextColorName = (colorName == "color.white".localized) ? "color.black".localized : "color.white".localized
        let turnMessage = "a11y.announce.genericTurn".localized(with: nextColorName)
        parts.append(turnMessage)

        let fullMessage = parts.joined(separator: " ")
        print("🎯 VoiceOver coup complet: \(fullMessage)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIAccessibility.post(notification: .announcement, argument: fullMessage)
        }
        #endif
    }

    /// Annonce complète d'un coup (Joueur vs IA) : coup + échec éventuel + tour
    func announceMoveComplete(piece: String, to: String, byPlayer: Bool, checkInfo: (pieces: [Piece], isCheck: Bool)) {
        #if os(iOS)
        var parts: [String] = []

        // 1. Le coup
        let moveMessage = byPlayer
            ? "a11y.announce.yourMove".localized(with: piece, to)
            : "a11y.announce.botMove".localized(with: piece, to)
        parts.append(moveMessage)

        // 2. L'échec éventuel
        if checkInfo.isCheck {
            let checkMessage = buildCheckMessage(threateningPieces: checkInfo.pieces)
            parts.append(checkMessage)
        }

        // 3. Le tour suivant
        let turnMessage = byPlayer
            ? "a11y.announce.botTurnNow".localized
            : "a11y.announce.yourTurnNow".localized
        parts.append(turnMessage)

        let fullMessage = parts.joined(separator: " ")
        print("🎯 VoiceOver coup complet: \(fullMessage)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIAccessibility.post(notification: .announcement, argument: fullMessage)
        }
        #endif
    }

    /// Annonce complète d'un roque (Joueur vs IA) : roque + échec éventuel + tour
    func announceCastleComplete(isKingside: Bool, byPlayer: Bool, checkInfo: (pieces: [Piece], isCheck: Bool)) {
        #if os(iOS)
        var parts: [String] = []

        // 1. Le roque
        let castleKey = isKingside ? "a11y.announce.yourCastleKingside" : "a11y.announce.yourCastleQueenside"
        let botCastleKey = isKingside ? "a11y.announce.botCastleKingside" : "a11y.announce.botCastleQueenside"
        let castleMessage = byPlayer ? castleKey.localized : botCastleKey.localized
        parts.append(castleMessage)

        // 2. L'échec éventuel
        if checkInfo.isCheck {
            let checkMessage = buildCheckMessage(threateningPieces: checkInfo.pieces)
            parts.append(checkMessage)
        }

        // 3. Le tour suivant
        let turnMessage = byPlayer
            ? "a11y.announce.botTurnNow".localized
            : "a11y.announce.yourTurnNow".localized
        parts.append(turnMessage)

        let fullMessage = parts.joined(separator: " ")
        print("🎯 VoiceOver roque complet: \(fullMessage)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIAccessibility.post(notification: .announcement, argument: fullMessage)
        }
        #endif
    }

    /// Annonce complète d'un roque (Joueur vs Joueur) : roque + échec éventuel + tour
    func announceGenericCastleComplete(colorName: String, isKingside: Bool, checkInfo: (pieces: [Piece], isCheck: Bool)) {
        #if os(iOS)
        var parts: [String] = []

        // 1. Le roque
        let castleKey = isKingside ? "a11y.announce.genericCastleKingside" : "a11y.announce.genericCastleQueenside"
        let castleMessage = castleKey.localized(with: colorName)
        parts.append(castleMessage)

        // 2. L'échec éventuel
        if checkInfo.isCheck {
            let checkMessage = buildCheckMessage(threateningPieces: checkInfo.pieces)
            parts.append(checkMessage)
        }

        // 3. Le tour suivant
        let nextColorName = (colorName == "color.white".localized) ? "color.black".localized : "color.white".localized
        let turnMessage = "a11y.announce.genericTurn".localized(with: nextColorName)
        parts.append(turnMessage)

        let fullMessage = parts.joined(separator: " ")
        print("🎯 VoiceOver roque complet: \(fullMessage)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIAccessibility.post(notification: .announcement, argument: fullMessage)
        }
        #endif
    }

    /// Construit le message d'échec
    private func buildCheckMessage(threateningPieces: [Piece]) -> String {
        if threateningPieces.isEmpty {
            return "a11y.announce.check".localized
        } else if threateningPieces.count == 1 {
            let pieceName = threateningPieces[0].type.localizedName
            return "a11y.announce.check.single".localized(with: pieceName)
        } else {
            let piece1Name = threateningPieces[0].type.localizedName
            let piece2Name = threateningPieces[1].type.localizedName
            return "a11y.announce.check.double".localized(with: piece1Name, piece2Name)
        }
    }

    /// Annonce à qui c'est le tour (utilisé uniquement pour les cas spéciaux)
    func announceTurn(for color: PieceColor, gameMode: GameMode) {
        #if os(iOS)
        let message: String
        if gameMode == .playerVsPlayer {
            let colorName = (color == .white) ? "color.white".localized : "color.black".localized
            message = "a11y.announce.genericTurn".localized(with: colorName)
        } else {
            // Player vs AI mode
            let isPlayerTurn = (color == .white) // Assuming human is white in PvAI
            message = isPlayerTurn
                ? "a11y.announce.yourTurnNow".localized
                : "a11y.announce.botTurnNow".localized
        }
        print("🎯 VoiceOver: \(message)")
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }

    // MARK: - Annonces d'échec (legacy, utilisé pour les cas spéciaux)

    /// Annonce un échec de manière descriptive
    func announceCheck(threateningPieces: [Piece]) {
        #if os(iOS)
        let message: String
        if threateningPieces.isEmpty {
            // Fallback, ne devrait pas être appelé sans menace
            message = "a11y.announce.check".localized
        } else if threateningPieces.count == 1 {
            let pieceName = threateningPieces[0].type.localizedName
            message = "a11y.announce.check.single".localized(with: pieceName)
        } else {
            // Échec double
            let piece1Name = threateningPieces[0].type.localizedName
            let piece2Name = threateningPieces[1].type.localizedName
            message = "a11y.announce.check.double".localized(with: piece1Name, piece2Name)
        }
        
        print("🎯 VoiceOver: \(message)")
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }

    /// Annonce un échec et mat (mode Joueur vs IA)
    func announceCheckmate(playerWon: Bool) {
        #if os(iOS)
        let message = playerWon
            ? "a11y.announce.checkmate.win".localized
            : "a11y.announce.checkmate.lose".localized

        print("🎯 VoiceOver: \(message)")
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }

    /// Annonce un échec et mat (mode Joueur vs Joueur)
    func announceCheckmateGeneric(winner: PieceColor) {
        #if os(iOS)
        let winnerName = winner == .white ? "color.white".localized : "color.black".localized
        let message = "a11y.announce.checkmate.generic".localized(with: winnerName)
        print("🎯 VoiceOver: \(message)")
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }

    // MARK: - Annonces de captures

    /// Annonce une capture de pièce par une couleur spécifique (pour Joueur vs Joueur)
    func announceGenericCapture(colorName: String, piece: String, at position: String, isEnPassant: Bool = false) {
        #if os(iOS)
        let message: String
        if isEnPassant {
            message = "a11y.announce.genericCaptureEnPassant".localized(with: colorName, piece, position)
        } else {
            message = "a11y.announce.genericCaptureAt".localized(with: colorName, piece, position)
        }
        print("🎯 VoiceOver: \(message)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        #endif
    }

    /// Annonce une capture de pièce par une couleur spécifique (pour Joueur vs Bot)
    func announceCapture(piece: String, at position: String, byPlayer: Bool, isEnPassant: Bool = false) {
        #if os(iOS)
        let message: String
        if isEnPassant {
            message = byPlayer
                ? "a11y.announce.capturedEnPassant".localized(with: piece, position)
                : "a11y.announce.botCapturedEnPassant".localized(with: piece, position)
        } else {
            message = byPlayer
                ? "a11y.announce.capturedAt".localized(with: piece, position)
                : "a11y.announce.botCapturedAt".localized(with: piece, position)
        }

        print("🎯 VoiceOver: \(message)")
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }

    // MARK: - Annonces de fin de partie

    /// Annonce un pat (match nul)
    func announceStalemate() {
        #if os(iOS)
        print("🎯 VoiceOver: \("a11y.announce.stalemate".localized)")
        UIAccessibility.post(
            notification: .announcement,
            argument: "a11y.announce.stalemate".localized
        )
        #endif
    }

    /// Annonce un match nul
    func announceDraw() {
        #if os(iOS)
        print("🎯 VoiceOver: \("a11y.announce.draw".localized)")
        UIAccessibility.post(
            notification: .announcement,
            argument: "a11y.announce.draw".localized
        )
        #endif
    }

    // MARK: - Annonces de coups spéciaux

    /// Annonce un roque (petit ou grand)
    func announceCastle(isKingside: Bool) {
        #if os(iOS)
        let key = isKingside ? "a11y.announce.castleKingside" : "a11y.announce.castleQueenside"
        print("🎯 VoiceOver: \(key.localized)")
        UIAccessibility.post(
            notification: .announcement,
            argument: key.localized
        )
        #endif
    }

    /// Annonce une promotion de pion
    func announcePromotion(to piece: String) {
        #if os(iOS)
        let message = "a11y.announce.promotion".localized(with: piece)
        print("🎯 VoiceOver: \(message)")
        UIAccessibility.post(
            notification: .announcement,
            argument: message
        )
        #endif
    }
}
