import Foundation
import SwiftData

@MainActor
protocol GamePersistenceProtocol {
    func save(gameState: GameState)
    func loadSnapshot(for mode: GameModeState) -> GameStateSnapshot?
    func clearSnapshot(for mode: GameModeState?)
    func archivePlayedGame(_ gameState: GameState)
    func loadPlayedGames() -> [PlayedGameRecord]
    func clearPlayedGames()
}

@MainActor
final class GamePersistenceController: GamePersistenceProtocol {
    static let shared = GamePersistenceController()

    let container: ModelContainer

    private init() {
        do {
            container = try ModelContainer(for: SavedGameEntity.self, PlayedGameEntity.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    func save(gameState: GameState) {
        let context = container.mainContext

        do {
            let snapshot = gameState.snapshot()
            let data = try JSONEncoder().encode(snapshot)
            let saveID = SavedGameEntity.currentGameID

            let entity: SavedGameEntity
            if let existing = try fetchEntity(withID: saveID, in: context) {
                entity = existing
            } else {
                let newEntity = SavedGameEntity(id: saveID, data: data)
                context.insert(newEntity)
                entity = newEntity
            }
            entity.data = data
            entity.updatedAt = snapshot.savedAt

            try context.save()
        } catch {
            Logger.warning("Failed to save game snapshot: \(error.localizedDescription)", subsystem: .persistence)
        }
    }

    func loadSnapshot(for mode: GameModeState) -> GameStateSnapshot? {
        let context = container.mainContext

        do {
            guard
                let entity = try fetchEntity(withID: SavedGameEntity.currentGameID, in: context)
            else { return nil }

            return try JSONDecoder().decode(GameStateSnapshot.self, from: entity.data)
        } catch {
            Logger.warning("Failed to load game snapshot: \(error.localizedDescription)", subsystem: .persistence)
            return nil
        }
    }

    func clearSnapshot(for mode: GameModeState? = nil) {
        let context = container.mainContext

        do {
            if let mode = mode {
                _ = mode
                if let entity = try fetchEntity(withID: SavedGameEntity.currentGameID, in: context) {
                    context.delete(entity)
                    try context.save()
                }
            } else {
                // Clear all snapshots if no mode specified
                let descriptor = FetchDescriptor<SavedGameEntity>()
                let allEntities = try context.fetch(descriptor)
                for entity in allEntities {
                    context.delete(entity)
                }
                try context.save()
            }
        } catch {
            Logger.warning("Failed to clear game snapshot: \(error.localizedDescription)", subsystem: .persistence)
        }
    }

    func archivePlayedGame(_ gameState: GameState) {
        guard !gameState.board.moveHistory.isEmpty else { return }

        let context = container.mainContext

        do {
            let record = PlayedGameRecord(
                id: UUID().uuidString,
                startedAt: gameState.startedAt,
                finishedAt: Date(),
                result: gameState.gameResult,
                moveHistory: gameState.board.moveHistory,
                moveHistoryDetailed: gameState.board.moveHistoryDetailed,
                mode: gameState.mode,
                difficulty: gameState.difficulty
            )
            let data = try JSONEncoder().encode(record)
            let entity = PlayedGameEntity(
                id: record.id,
                data: data,
                startedAt: record.startedAt,
                finishedAt: record.finishedAt,
                moveCount: record.moveCount,
                resultText: record.resultText
            )
            context.insert(entity)
            try context.save()
        } catch {
            Logger.warning("Failed to archive played game: \(error.localizedDescription)", subsystem: .persistence)
        }
    }

    func loadPlayedGames() -> [PlayedGameRecord] {
        let context = container.mainContext

        do {
            let descriptor = FetchDescriptor<PlayedGameEntity>(
                sortBy: [SortDescriptor(\.finishedAt, order: .reverse)]
            )
            return try context.fetch(descriptor).compactMap { entity in
                try? JSONDecoder().decode(PlayedGameRecord.self, from: entity.data)
            }
        } catch {
            Logger.warning("Failed to load played games: \(error.localizedDescription)", subsystem: .persistence)
            return []
        }
    }

    func clearPlayedGames() {
        let context = container.mainContext

        do {
            let descriptor = FetchDescriptor<PlayedGameEntity>()
            let allEntities = try context.fetch(descriptor)
            for entity in allEntities {
                context.delete(entity)
            }
            try context.save()
        } catch {
            Logger.warning("Failed to clear played games: \(error.localizedDescription)", subsystem: .persistence)
        }
    }

    private func fetchEntity(withID id: String, in context: ModelContext) throws -> SavedGameEntity? {
        let descriptor = FetchDescriptor<SavedGameEntity>(
            predicate: #Predicate { $0.id == id },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        return try context.fetch(descriptor).first
    }
}
