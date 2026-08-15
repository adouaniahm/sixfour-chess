//
//  HapticService.swift
//  SixFourChess
//
//  Haptic Feedback Service for tactile responses
//

import Foundation
import UIKit

// MARK: - Protocol

protocol HapticServiceProtocol {
    func pieceSelected()
    func moveMade()
    func pieceCaptured()
    func check()
    func checkmate()
    func stalemate()
    func error()
}

// MARK: - Implementation

final class HapticService: HapticServiceProtocol {
    static let shared = HapticService()

    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    private init() {
        prepareGenerators()
    }

    private func prepareGenerators() {
        selectionFeedback.prepare()
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notificationFeedback.prepare()
    }

    func pieceSelected() {
        selectionFeedback.selectionChanged()
        selectionFeedback.prepare()
    }

    func moveMade() {
        impactLight.impactOccurred()
        impactLight.prepare()
    }

    func pieceCaptured() {
        impactMedium.impactOccurred()
        impactMedium.prepare()
    }

    func check() {
        impactHeavy.impactOccurred()
        impactHeavy.prepare()
    }

    func checkmate() {
        notificationFeedback.notificationOccurred(.success)
        notificationFeedback.prepare()
    }

    func stalemate() {
        notificationFeedback.notificationOccurred(.warning)
        notificationFeedback.prepare()
    }

    func error() {
        notificationFeedback.notificationOccurred(.error)
        notificationFeedback.prepare()
    }
}
