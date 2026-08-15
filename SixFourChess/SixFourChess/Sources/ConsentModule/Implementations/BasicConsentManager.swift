import Foundation
import Observation

/// Gestionnaire de consentement basique
@Observable
final class BasicConsentManager: ConsentManagerProtocol {
    static let shared = BasicConsentManager()

    private let storage: ConsentStorageProtocol
    // lastUpdate is no longer needed with @Observable as properties are tracked automatically
    // But to force updates if no stored property changes, we can keep a tracked property.
    // However, since storage is private and its changes are side-effects, we might need a property to signal change.
    var lastUpdate: Date = Date()

    init(storage: ConsentStorageProtocol = UserDefaultsConsentStorage()) {
        self.storage = storage
    }

    func hasConsent(for permission: ConsentPermission) -> Bool {
        // Accessing a tracked property to register dependency
        _ = lastUpdate 
        let status = storage.getConsent(for: permission)
        return status == .granted
    }

    func grantConsent(for permissions: Set<ConsentPermission>) {
        for permission in permissions {
            storage.saveConsent(.granted, for: permission)
        }
        lastUpdate = Date() // Signal change
        Logger.success("Granted consent for: \(permissions.map { $0.rawValue })", subsystem: .consent)
    }

    func revokeConsent(for permissions: Set<ConsentPermission>) {
        for permission in permissions {
            storage.saveConsent(.denied, for: permission)
        }
        lastUpdate = Date() // Signal change
        Logger.info("Revoked consent for: \(permissions.map { $0.rawValue })", subsystem: .consent)
    }

    func getAllConsents() -> [ConsentPermission: ConsentStatus] {
        var consents: [ConsentPermission: ConsentStatus] = [:]
        for permission in ConsentPermission.allCases {
            consents[permission] = storage.getConsent(for: permission)
        }
        return consents
    }
}
