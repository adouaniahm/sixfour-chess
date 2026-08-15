//
//  SixFourChessAppApp.swift
//  SixFourChessApp
//
//  Created by Ahmed Adouani on 02/11/2025.
//

import SwiftUI
import SwiftData
import AVFoundation
import UIKit // Required for UIApplicationDelegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure audio session for proper mixing with other audio
        configureAudioSession()

        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Re-activate audio session when app becomes active
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            // Activate without interrupting other audio
            try audioSession.setActive(true, options: [])
            print("✅ [AppDelegate] Audio session configured for ambient playback with mixWithOthers")
        } catch {
            print("⚠️ [AppDelegate] Failed to configure audio session: \(error.localizedDescription)")
        }
    }
}

@main
struct SixFourChessAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    private static var isUITesting: Bool {
        CommandLine.arguments.contains("--uitesting")
    }

    // In UI testing mode, reset game settings to AI mode for a clean slate
    private static let _uiTestingSetup: Void = {
        if isUITesting {
            UserSettingsStorage.shared.save(gameMode: .playerVsAI, difficulty: .medium)
        }
    }()

    @State private var showSplash = !SixFourChessAppApp.isUITesting
    @State private var showConsentBanner = false
    @State private var consentCompleted = SixFourChessAppApp.isUITesting
    private let persistenceController = GamePersistenceController.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        let _ = Self._uiTestingSetup
        WindowGroup {
            Group {
                if showSplash {
                    SplashScreenView {
                        withAnimation {
                            showSplash = false
                            // Vérifier si le consentement a déjà été donné
                            checkConsentStatus()
                        }
                    }
                } else if showConsentBanner {
                    // Afficher la bannière CMP en plein écran (sans bouton fermer)
                    ConsentModule.makeSimpleConsentBannerView(
                        onConsentGiven: {
                            print("✅ [App] Initial consent given")
                            withAnimation {
                                showConsentBanner = false
                                consentCompleted = true
                            }
                        },
                        onConsentDenied: {
                            print("ℹ️ [App] Consent banner dismissed")
                            withAnimation {
                                showConsentBanner = false
                                consentCompleted = true
                            }
                        },
                        showCloseButton: false
                    )
                } else {
                    ReduxGameView()
                        .withAppReduxStore() // Inject Redux mutation store
                }
            }
            .tint(AppTheme.accentColor(for: colorScheme))
        }
        .modelContainer(persistenceController.container)
    }

    private func checkConsentStatus() {
        // Vérifier si l'utilisateur a déjà donné son consentement
        let consents = ConsentModule.manager.getAllConsents()
        let hasAnyConsent = consents.values.contains { $0 == .granted || $0 == .denied }

        if hasAnyConsent {
            // L'utilisateur a déjà vu la bannière CMP
            print("ℹ️ [App] Consent already given, skipping banner")
            consentCompleted = true
            showConsentBanner = false
        } else {
            // Première utilisation, afficher la bannière
            print("ℹ️ [App] First launch, showing consent banner")
            showConsentBanner = true
        }
    }
}
