import Foundation

/// Represents a position on the board, using 0-7 for row and column.
/// `nonisolated`: pure value type (two `Int`s) used from every actor.
/// Synthesized conformances (`Equatable`, `Hashable`, `Codable`) are also nonisolated.
nonisolated struct Position: Codable, Equatable, Hashable, Sendable {
    let row: Int
    let col: Int

    nonisolated init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }

    nonisolated init?(notation: String) {
        guard notation.count == 2,
              let colChar = notation.first,
              let rowChar = notation.last,
              let col = "abcdefgh".firstIndex(of: colChar),
              let row = Int(String(rowChar)) else {
            return nil
        }
        self.col = "abcdefgh".distance(from: "abcdefgh".startIndex, to: col)
        self.row = 8 - row
    }

    nonisolated var isValid: Bool {
        row >= 0 && row < 8 && col >= 0 && col < 8
    }

    nonisolated var notation: String {
        let colChar = "abcdefgh"["abcdefgh".index("abcdefgh".startIndex, offsetBy: col)]
        let rowNum = 8 - row
        return "\(colChar)\(rowNum)"
    }

    nonisolated func offset(row: Int, col: Int) -> Position {
        Position(row: self.row + row, col: self.col + col)
    }
}
