//
//  AppVersion.swift
//  SixFourChess
//
//  Utility to access the app version from `Bundle.main`.
//  Avoids hardcoded versions in code and localizations.
//

import Foundation

/// Acces centralise a la version de l'app (depuis Info.plist / Build Settings).
enum AppVersion {
    /// Version courte (ex: "1.0.0") — CFBundleShortVersionString
    static var short: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    /// Numero de build (ex: "42") — CFBundleVersion
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    /// Chaine d'affichage complete (ex: "1.0.0 (42)")
    static var displayString: String {
        "\(short) (\(build))"
    }
}
