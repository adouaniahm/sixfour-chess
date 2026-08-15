import Foundation

/// Protocole du gestionnaire de consentement
protocol ConsentManagerProtocol {
    func hasConsent(for permission: ConsentPermission) -> Bool
    func grantConsent(for permissions: Set<ConsentPermission>)
    func revokeConsent(for permissions: Set<ConsentPermission>)
    func getAllConsents() -> [ConsentPermission: ConsentStatus]
}
