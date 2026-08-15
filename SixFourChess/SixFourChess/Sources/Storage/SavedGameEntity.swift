import Foundation
import SwiftData

@Model
final class SavedGameEntity {
    @Attribute(.unique) var id: String
    var data: Data
    var updatedAt: Date

    init(id: String, data: Data, updatedAt: Date = Date()) {
        self.id = id
        self.data = data
        self.updatedAt = updatedAt
    }

    static let currentGameID = "currentGame"
}

@Model
final class PlayedGameEntity {
    @Attribute(.unique) var id: String
    var data: Data
    var startedAt: Date
    var finishedAt: Date
    var moveCount: Int
    var resultText: String

    init(
        id: String,
        data: Data,
        startedAt: Date,
        finishedAt: Date,
        moveCount: Int,
        resultText: String
    ) {
        self.id = id
        self.data = data
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.moveCount = moveCount
        self.resultText = resultText
    }
}
