import Foundation

/// Convenience extension for localized strings.
extension String {
    /// Returns the localized string for this key.
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }

    /// Returns the localized string formatted with arguments.
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}
