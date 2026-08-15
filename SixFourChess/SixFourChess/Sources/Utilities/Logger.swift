//
//  Logger.swift
//  SixFourChess
//
//  Conditional logging utility - only logs in DEBUG builds
//

import Foundation
import os.log

/// Unified logging system for SixFourChess
/// Only outputs logs in DEBUG builds
enum Logger {

    // MARK: - Subsystems

    enum Subsystem: String {
        case game = "🎮"
        case online = "🌐"
        case redux = "📦"
        case analytics = "📊"
        case consent = "🔒"
        case persistence = "💾"
        case multiplayer = "👥"
        case ui = "🖼️"
        case viewer = "📺"
        case parser = "🔍"
        case audio = "🔊"
        case general = "ℹ️"
    }

    // MARK: - Log Levels

    enum Level: String {
        case debug = "🔵"
        case info = "🟢"
        case warning = "🟡"
        case error = "🔴"
        case success = "✅"
    }

    // MARK: - Logging Methods

    /// Log a message (only in DEBUG builds).
    /// `nonisolated` because logging must be accessible from any actor.
    nonisolated static func log(
        _ message: String,
        subsystem: Subsystem = .general,
        level: Level = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        let prefix = "\(level.rawValue) [\(subsystem.rawValue) \(fileName):\(line)]"
        print("\(prefix) \(message)")
        #endif
    }

    /// Convenience methods - all `nonisolated` so they can be called from any actor.
    nonisolated static func debug(_ message: String, subsystem: Subsystem = .general) {
        log(message, subsystem: subsystem, level: .debug)
    }

    nonisolated static func info(_ message: String, subsystem: Subsystem = .general) {
        log(message, subsystem: subsystem, level: .info)
    }

    nonisolated static func warning(_ message: String, subsystem: Subsystem = .general) {
        log(message, subsystem: subsystem, level: .warning)
    }

    nonisolated static func error(_ message: String, subsystem: Subsystem = .general) {
        log(message, subsystem: subsystem, level: .error)
    }

    nonisolated static func success(_ message: String, subsystem: Subsystem = .general) {
        log(message, subsystem: subsystem, level: .success)
    }
}
