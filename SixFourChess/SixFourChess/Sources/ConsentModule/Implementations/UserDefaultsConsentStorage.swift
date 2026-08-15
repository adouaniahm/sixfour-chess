import Foundation

/// Stores consent choices in UserDefaults.
final class UserDefaultsConsentStorage: ConsentStorageProtocol {
    private let userDefaults: UserDefaults
    private let keyPrefix = "consent_"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func saveConsent(_ status: ConsentStatus, for permission: ConsentPermission) {
        let key = keyPrefix + permission.rawValue
        userDefaults.set(status.rawValue, forKey: key)
    }

    func getConsent(for permission: ConsentPermission) -> ConsentStatus {
        let key = keyPrefix + permission.rawValue
        guard let rawValue = userDefaults.string(forKey: key),
              let status = ConsentStatus(rawValue: rawValue) else {
            return .notAsked
        }
        return status
    }

    func clearAllConsents() {
        for permission in ConsentPermission.allCases {
            let key = keyPrefix + permission.rawValue
            userDefaults.removeObject(forKey: key)
        }
    }
}
