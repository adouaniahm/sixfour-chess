//
//  AnalyticsService.swift
//  SixFourChess
//
//  Service for tracking analytics events
//  Keeps analytics behind a local protocol.
//

import Foundation

/// Protocol for Analytics Service
protocol AnalyticsServiceProtocol {
    func logEvent(_ name: String, parameters: [String: Any]?)
    func logScreen(name: String, class: String)
    func setUserProperty(_ value: String?, forName name: String)
    func setUserId(_ userId: String?)
}

/// Concrete implementation. Logging is local-only in the current release.
final class AnalyticsService: AnalyticsServiceProtocol {
    static let shared = AnalyticsService()
    
    private var consentManager: ConsentManagerProtocol?
    
    private init() {}
    
    /// Configure the service with dependencies
    func configure(consentManager: ConsentManagerProtocol) {
        self.consentManager = consentManager
        // Initial sync
        updateCollectionEnabled()
    }
    
    private func updateCollectionEnabled() {
        guard let manager = consentManager else { return }
        let isEnabled = manager.hasConsent(for: .performanceAnalytics)
        if !isEnabled {
            Logger.info("Analytics collection disabled by user consent", subsystem: .analytics)
        }
    }

    private var hasConsent: Bool {
        guard let manager = consentManager else {
            Logger.warning("ConsentManager not configured. Blocking analytics by default.", subsystem: .analytics)
            return false
        }
        
        return manager.hasConsent(for: .performanceAnalytics)
    }
    
    func logEvent(_ name: String, parameters: [String: Any]?) {
        guard hasConsent else { return }
        Logger.debug("(Analytics) Event: \(name) params: \(String(describing: parameters))", subsystem: .analytics)
    }
    
    func logScreen(name: String, class className: String) {
        guard hasConsent else { return }
        Logger.debug("(Analytics) Screen View: \(name) [\(className)]", subsystem: .analytics)
    }
    
    func setUserProperty(_ value: String?, forName name: String) {
        guard hasConsent else { return }
        Logger.debug("(Analytics) User property \(name)=\(value ?? "nil")", subsystem: .analytics)
    }
    
    func setUserId(_ userId: String?) {
        guard hasConsent else { return }
        Logger.debug("(Analytics) User id \(userId ?? "nil")", subsystem: .analytics)
    }
}

// MARK: - Event Helpers

extension AnalyticsService {
    enum Event {
        static let gameStarted = "game_started"
        static let gameFinished = "game_finished"
        static let moveMade = "move_made"
        static let gameAbandoned = "game_abandoned"
    }
    
    enum Param {
        static let gameMode = "game_mode"
        static let difficulty = "difficulty"
        static let result = "result"
        static let color = "player_color"
        static let moveCount = "move_count"
    }
}
