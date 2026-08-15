import Foundation

/// Protocole de stockage des consentements
protocol ConsentStorageProtocol {
    func saveConsent(_ status: ConsentStatus, for permission: ConsentPermission)
    func getConsent(for permission: ConsentPermission) -> ConsentStatus
    func clearAllConsents()
}
