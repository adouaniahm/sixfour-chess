//
//  GameModeState.swift
//  SixFourChess
//

import Foundation

enum GameModeState: Equatable, Codable {
    case ai(AIConfig)

    var isAIMode: Bool { true }

    var aiConfig: AIConfig? {
        if case .ai(let config) = self { return config }
        return nil
    }

    var legacyGameMode: GameMode {
        .playerVsAI
    }

    static func from(legacyMode: GameMode, difficulty: AIDifficulty = .medium) -> GameModeState {
        _ = legacyMode
        return .ai(AIConfig(whiteEnabled: false, blackEnabled: true, difficulty: difficulty))
    }
}

struct AIConfig: Equatable, Codable {
    let whiteEnabled: Bool
    let blackEnabled: Bool
    let difficulty: AIDifficulty

    func isAIEnabled(for color: PieceColor) -> Bool {
        switch color {
        case .white: return whiteEnabled
        case .black: return blackEnabled
        }
    }
}
