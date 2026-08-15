import SwiftUI

/// Consent management module (CMP).
enum ConsentModule {

    /// Shared consent manager.
    static let manager: ConsentManagerProtocol = BasicConsentManager.shared

    // MARK: - Consent checks

    /// Checks whether all required permissions have been granted.
    static func hasAllRequiredConsents() -> Bool {
        let required = ConsentCategory.allCategories
            .filter { $0.isRequired }
            .flatMap { $0.permissions }

        return required.allSatisfy { manager.hasConsent(for: $0) }
    }

    // MARK: - Views

    /// Creates the simplified consent banner (OneTrust-style).
    static func makeSimpleConsentBannerView(
        onConsentGiven: @escaping () -> Void,
        onConsentDenied: @escaping () -> Void,
        showCloseButton: Bool = true
    ) -> some View {
        SimpleConsentBannerView(
            manager: manager,
            onConsentGiven: onConsentGiven,
            onConsentDenied: onConsentDenied,
            showCloseButton: showCloseButton
        )
    }

    /// Creates the consent settings view.
    static func makeConsentSettingsView() -> some View {
        ConsentSettingsView(manager: manager)
    }

    /// Creates the privacy policy view.
    static func makePrivacyPolicyView() -> some View {
        PrivacyPolicyView()
    }
}
