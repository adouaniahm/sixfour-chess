//
//  DependencyInjection.swift
//  SixFourChess
//
//  Lightweight Dependency Injection System
//  Modern, type-safe, and testable.
//

import Foundation

// MARK: - Dependency Keys

/// Container for all application dependencies.
/// This struct acts as the registry. To add a dependency, extend this struct.
struct DependencyValues {
    static var current = DependencyValues()
    
    // Default implementations are defined here or in extensions
}

// MARK: - Property Wrapper

/// A property wrapper for accessing dependencies.
///
/// Usage:
/// ```
/// @Dependency(\.analyticsService) var analyticsService
/// ```
@propertyWrapper
struct Dependency<T> {
    private let keyPath: WritableKeyPath<DependencyValues, T>
    
    var wrappedValue: T {
        get { DependencyValues.current[keyPath: keyPath] }
        set { DependencyValues.current[keyPath: keyPath] = newValue }
    }
    
    init(_ keyPath: WritableKeyPath<DependencyValues, T>) {
        self.keyPath = keyPath
    }
}

// MARK: - Definition of Dependencies

// Extension to register services
extension DependencyValues {
    /// The analytics service
    var analyticsService: AnalyticsServiceProtocol {
        get { self[AnalyticsServiceKey.self] }
        set { self[AnalyticsServiceKey.self] = newValue }
    }
    
    /// The persistence controller
    var persistence: GamePersistenceProtocol {
        get { self[PersistenceKey.self] }
        set { self[PersistenceKey.self] = newValue }
    }
    
    /// User settings storage
    var userSettings: UserSettingsStorageProtocol {
        get { self[UserSettingsKey.self] }
        set { self[UserSettingsKey.self] = newValue }
    }
    
    /// Installation identifier
    var installationID: InstallationIdentifierProtocol {
        get { self[InstallationIDKey.self] }
        set { self[InstallationIDKey.self] = newValue }
    }
    
    /// Consent manager
    var consentManager: ConsentManagerProtocol {
        get { self[ConsentManagerKey.self] }
        set { self[ConsentManagerKey.self] = newValue }
    }

    /// Accessibility service for VoiceOver
    var accessibilityService: AccessibilityServiceProtocol {
        get { self[AccessibilityServiceKey.self] }
        set { self[AccessibilityServiceKey.self] = newValue }
    }

    /// Audio service for game sounds
    var audioService: AudioServiceProtocol {
        get { self[AudioServiceKey.self] }
        set { self[AudioServiceKey.self] = newValue }
    }

    /// Haptic service for tactile feedback
    var hapticService: HapticServiceProtocol {
        get { self[HapticServiceKey.self] }
        set { self[HapticServiceKey.self] = newValue }
    }

}

// MARK: - Keys Implementation

private struct AnalyticsServiceKey: DependencyKey {
    static var liveValue: AnalyticsServiceProtocol = AnalyticsService.shared
}

private struct PersistenceKey: DependencyKey {
    static var liveValue: GamePersistenceProtocol = GamePersistenceController.shared
}

private struct UserSettingsKey: DependencyKey {
    static var liveValue: UserSettingsStorageProtocol = UserSettingsStorage.shared
}

private struct InstallationIDKey: DependencyKey {
    static var liveValue: InstallationIdentifierProtocol = InstallationIdentifier.shared
}

private struct ConsentManagerKey: DependencyKey {
    static var liveValue: ConsentManagerProtocol = BasicConsentManager.shared
}

private struct AccessibilityServiceKey: DependencyKey {
    static var liveValue: AccessibilityServiceProtocol = AccessibilityService.shared
}

private struct AudioServiceKey: DependencyKey {
    static var liveValue: AudioServiceProtocol = AudioService.shared
}

private struct HapticServiceKey: DependencyKey {
    static var liveValue: HapticServiceProtocol = HapticService.shared
}

// MARK: - Infrastructure

protocol DependencyKey {
    associatedtype Value
    static var liveValue: Value { get }
}

extension DependencyValues {
    private static var storage: [String: Any] = [:]
    
    subscript<K>(key: K.Type) -> K.Value where K: DependencyKey {
        get {
            if let value = Self.storage[String(describing: key)] as? K.Value {
                return value
            }
            return key.liveValue
        }
        set {
            Self.storage[String(describing: key)] = newValue
        }
    }
}
