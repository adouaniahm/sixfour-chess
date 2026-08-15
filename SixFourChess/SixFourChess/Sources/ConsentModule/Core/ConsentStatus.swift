import Foundation

/// Statut du consentement
enum ConsentStatus: String, Codable {
    case notAsked
    case granted
    case denied
}
