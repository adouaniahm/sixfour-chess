import Foundation

protocol UserSettingsStorageProtocol {
    func save(gameMode: GameMode, difficulty: AIDifficulty)
    func load() -> (gameMode: GameMode, difficulty: AIDifficulty)?
    func saveSoundEnabled(_ enabled: Bool)
    func loadSoundEnabled() -> Bool
    func saveMoveCommentsEnabled(_ enabled: Bool)
    func loadMoveCommentsEnabled() -> Bool
}

/// Simple wrapper around `UserDefaults` to persist game preferences
struct UserSettingsStorage: UserSettingsStorageProtocol {
    static let shared = UserSettingsStorage()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Keys {
        static let gameMode = "userSettings.gameMode"
        static let difficulty = "userSettings.difficulty"
        static let soundEnabled = "userSettings.soundEnabled"
        static let moveCommentsEnabled = "userSettings.moveCommentsEnabled"
    }

    func save(gameMode: GameMode, difficulty: AIDifficulty) {
        defaults.set(gameMode.rawValue, forKey: Keys.gameMode)
        defaults.set(difficulty.rawValue, forKey: Keys.difficulty)
    }

    func load() -> (gameMode: GameMode, difficulty: AIDifficulty)? {
        guard
            let modeRawValue = defaults.string(forKey: Keys.gameMode),
            let difficultyRawValue = defaults.string(forKey: Keys.difficulty),
            let mode = GameMode(rawValue: modeRawValue),
            let difficulty = AIDifficulty(rawValue: difficultyRawValue)
        else {
            return nil
        }

        return (mode, difficulty)
    }

    func saveSoundEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.soundEnabled)
    }

    func loadSoundEnabled() -> Bool {
        // Default to true (sounds enabled)
        return defaults.object(forKey: Keys.soundEnabled) as? Bool ?? true
    }

    func saveMoveCommentsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.moveCommentsEnabled)
    }

    func loadMoveCommentsEnabled() -> Bool {
        return defaults.object(forKey: Keys.moveCommentsEnabled) as? Bool ?? true
    }
}
