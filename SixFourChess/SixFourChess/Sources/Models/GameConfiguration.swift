import Foundation
import SwiftUI

enum GameMode: String, Codable, CaseIterable {
    case playerVsAI

    var localizedName: String {
        "mode.playerVsBot".localized
    }

    var localizedDescription: String {
        "mode.playerVsBot.desc".localized
    }

    var icon: String {
        "person.fill"
    }

    var secondaryIcon: String? {
        "cpu.fill"
    }

    var accentColor: Color {
        .orange
    }

    var aiConfiguration: (whiteAIEnabled: Bool, blackAIEnabled: Bool) {
        (false, true)
    }

    var normalizedForCurrentRelease: GameMode {
        .playerVsAI
    }
}

enum AIDifficulty: String, Codable, CaseIterable {
    case easy
    case medium
    case hard
    case expert
    case master

    var localizedName: String {
        switch self {
        case .easy: return "difficulty.easy".localized
        case .medium: return "difficulty.medium".localized
        case .hard: return "difficulty.hard".localized
        case .expert: return "difficulty.expert".localized
        case .master: return "difficulty.master".localized
        }
    }

    var depth: Int {
        switch self {
        case .easy: return 2
        case .medium: return 3
        case .hard: return 4
        case .expert: return 5
        case .master: return 5
        }
    }

    var localizedDescription: String {
        switch self {
        case .easy: return "ui.perfect.beginners".localized
        case .medium: return "ui.good.practice".localized
        case .hard: return "ui.challenge.experienced".localized
        case .expert: return "ui.very.hard".localized
        case .master: return "ui.master.cloud".localized
        }
    }

    var icon: String {
        switch self {
        case .easy: return "leaf.fill"
        case .medium: return "flame.fill"
        case .hard: return "bolt.fill"
        case .expert: return "crown.fill"
        case .master: return "network"
        }
    }

    var accentColor: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        case .expert: return .purple
        case .master: return .cyan
        }
    }
}
