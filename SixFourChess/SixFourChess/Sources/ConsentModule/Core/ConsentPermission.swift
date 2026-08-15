import Foundation

/// Consent permission types.
enum ConsentPermission: String, CaseIterable, Codable {
    case gameDataStorage = "game_data_storage"
    case performanceAnalytics = "performance_analytics"
    /// Cloud AI analysis (Master mode) - sends FEN positions to lichess.org and stockfish.online.
    /// No personal data is transmitted. Listed here for GDPR transparency under Art. 13.
    case cloudAI = "cloud_ai_analysis"

    var localizedName: String {
        switch self {
        case .gameDataStorage:
            return NSLocalizedString("consent.permission.storage.name", comment: "")
        case .performanceAnalytics:
            return NSLocalizedString("consent.permission.analytics.name", comment: "")
        case .cloudAI:
            return NSLocalizedString("consent.permission.cloudai.name", comment: "")
        }
    }

    var localizedDescription: String {
        switch self {
        case .gameDataStorage:
            return NSLocalizedString("consent.permission.storage.desc", comment: "")
        case .performanceAnalytics:
            return NSLocalizedString("consent.permission.analytics.desc", comment: "")
        case .cloudAI:
            return NSLocalizedString("consent.permission.cloudai.desc", comment: "")
        }
    }
}
