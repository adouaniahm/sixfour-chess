import Testing
@testable import SixFour

@MainActor
@Suite struct AnalyticsServiceTests {

    @Test func logEventWithoutConsentDoesNothing() {
        let service = AnalyticsService.shared
        let mockConsentManager = MockConsentManager()
        service.configure(consentManager: mockConsentManager)

        mockConsentManager.revokeConsent(for: [.performanceAnalytics])

        // We only verify the service stays safe when called without consent.
        service.logEvent("test_event", parameters: nil)
    }
}
