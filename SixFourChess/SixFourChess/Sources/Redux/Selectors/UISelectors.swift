//
//  UISelectors.swift
//  SixFourChess
//
//  Redux UI Selectors
//

import Foundation

/// Selectors for UI state
struct UISelectors {
    /// Check if settings are shown
    static func isShowingSettings(state: UIState) -> Bool {
        return state.showSettings
    }

    /// Check if promotion alert is shown
    static func isShowingPromotionAlert(state: UIState) -> Bool {
        return state.showPromotionAlert
    }

    /// Check if AI turn alert is shown
    static func isShowingAITurnAlert(state: UIState) -> Bool {
        return state.showAITurnAlert
    }

    /// Check if hint alert is shown
    static func isShowingHintAlert(state: UIState) -> Bool {
        return state.showHintAlert
    }

    /// Get unique promotion piece types (always Q, R, B, N in order)
    static func promotionOptions(state: UIState) -> [PieceType] {
        var seen = Set<PieceType>()
        return state.promotionMoves.compactMap { $0.promotionType }.filter { seen.insert($0).inserted }
    }

    /// Get current hint text
    static func hintText(state: UIState) -> String {
        return state.currentHint
    }
}
