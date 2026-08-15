import Foundation

protocol InstallationIdentifierProtocol {
    var value: String { get }
    var isFreshInstall: Bool { get }
}

/// Provides a per-installation identifier and signals when the app is freshly installed.
final class InstallationIdentifier: InstallationIdentifierProtocol {
    static let shared = InstallationIdentifier()

    private let idKey = "sixfour.installation.id"
    private let hasRunKey = "sixfour.installation.hasRun"

    /// Unique identifier generated for the current installation.
    let value: String

    /// Indicates whether this is the first launch after installing/reinstalling the app.
    let isFreshInstall: Bool

    private init() {
        let defaults = UserDefaults.standard

        if let existingID = defaults.string(forKey: idKey) {
            value = existingID
        } else {
            let newID = UUID().uuidString
            defaults.set(newID, forKey: idKey)
            value = newID
        }

        if defaults.bool(forKey: hasRunKey) {
            isFreshInstall = false
        } else {
            isFreshInstall = true
            defaults.set(true, forKey: hasRunKey)
        }
    }
}
