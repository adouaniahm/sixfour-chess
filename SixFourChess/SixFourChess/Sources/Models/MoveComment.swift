//
//  MoveComment.swift
//  SixFourChess
//
//  Model representing a move-analysis comment.
//

import Foundation

struct MoveComment: Equatable, Sendable {

    enum Quality: Equatable, Sendable {
        case brilliant
        case good
        case inaccuracy
        case mistake
        case blunder
    }

    let quality: Quality
    let message: String
    let icon: String        // SF Symbol name.
    let accentColor: String // Hex color, for example "#FFD700".
}
