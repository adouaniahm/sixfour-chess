//
//  PieceType+Localized.swift
//  SixFourChess
//
//  Localized names for piece types (pawn, knight, bishop, rook, queen, king).
//  Used in the promotion alert and accessibility labels.

import Foundation

extension PieceType {
    /// Localized piece name, for example "Cavalier" in French or "Knight" in English.
    var localizedName: String {
        switch self {
        case .pawn: return "piece.pawn".localized
        case .knight: return "piece.knight".localized
        case .bishop: return "piece.bishop".localized
        case .rook: return "piece.rook".localized
        case .queen: return "piece.queen".localized
        case .king: return "piece.king".localized
        }
    }
}
