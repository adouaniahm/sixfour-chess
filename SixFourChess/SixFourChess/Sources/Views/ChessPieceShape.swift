//
//  ChessPieceShape.swift
//  SixFourChess
//
//  Vector shapes for the 6 chess piece types.
//  Each piece is drawn with SwiftUI `Path`s relative to the received rect.
//
//  Coordinate system: every shape is drawn relative
//  to the received `rect` (the board square). Positions use:
//    - `rect.midX` / `rect.midY` for the center
//    - `rect.width` / `rect.height` for relative proportions
//    - `rect.maxY` for the bottom (piece base)
//
//  Each `*Path(in:)` method draws a complete piece:
//    `pawnPath`   : circle (head) + trapezoid (body) + rectangle (base)
//    `knightPath` : L-shaped head with ear + curved neck + base
//    `bishopPath` : mitre tip + oval body + base
//    `rookPath`   : battlements (3 teeth) + rectangular body + base
//    `queenPath`  : crown (5 points) + tapered body + base
//    `kingPath`   : cross (top) + tapered body + base

import SwiftUI

struct ChessPieceShape: Shape {
    let type: PieceType

    func path(in rect: CGRect) -> Path {
        switch type {
        case .pawn:
            return pawnPath(in: rect)
        case .knight:
            return knightPath(in: rect)
        case .bishop:
            return bishopPath(in: rect)
        case .rook:
            return rookPath(in: rect)
        case .queen:
            return queenPath(in: rect)
        case .king:
            return kingPath(in: rect)
        }
    }

    private func pawnPath(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // Head (circle).
        path.addEllipse(in: CGRect(
            x: center.x - rect.width * 0.15,
            y: rect.minY + rect.height * 0.1,
            width: rect.width * 0.3,
            height: rect.height * 0.3
        ))

        // Body (trapezoid).
        path.move(to: CGPoint(x: center.x - rect.width * 0.12, y: rect.minY + rect.height * 0.4))
        path.addLine(to: CGPoint(x: center.x - rect.width * 0.25, y: rect.maxY - rect.height * 0.15))
        path.addLine(to: CGPoint(x: center.x + rect.width * 0.25, y: rect.maxY - rect.height * 0.15))
        path.addLine(to: CGPoint(x: center.x + rect.width * 0.12, y: rect.minY + rect.height * 0.4))
        path.closeSubpath()

        // Base
        path.addRect(CGRect(
            x: center.x - rect.width * 0.3,
            y: rect.maxY - rect.height * 0.15,
            width: rect.width * 0.6,
            height: rect.height * 0.15
        ))

        return path
    }

    private func knightPath(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // Horse head with a recognizable profile.
        // Ear.
        path.move(to: CGPoint(x: center.x - rect.width * 0.05, y: rect.minY + rect.height * 0.05))
        path.addCurve(
            to: CGPoint(x: center.x + rect.width * 0.05, y: rect.minY + rect.height * 0.12),
            control1: CGPoint(x: center.x - rect.width * 0.02, y: rect.minY),
            control2: CGPoint(x: center.x + rect.width * 0.02, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: center.x, y: rect.minY + rect.height * 0.15))
        path.closeSubpath()

        // Head profile (forehead, nose, mouth).
        path.move(to: CGPoint(x: center.x - rect.width * 0.1, y: rect.minY + rect.height * 0.15))
        // Forehead.
        path.addCurve(
            to: CGPoint(x: center.x + rect.width * 0.25, y: rect.minY + rect.height * 0.25),
            control1: CGPoint(x: center.x + rect.width * 0.1, y: rect.minY + rect.height * 0.08),
            control2: CGPoint(x: center.x + rect.width * 0.25, y: rect.minY + rect.height * 0.15)
        )
        // Nose.
        path.addCurve(
            to: CGPoint(x: center.x + rect.width * 0.3, y: rect.minY + rect.height * 0.38),
            control1: CGPoint(x: center.x + rect.width * 0.3, y: rect.minY + rect.height * 0.28),
            control2: CGPoint(x: center.x + rect.width * 0.35, y: rect.minY + rect.height * 0.33)
        )
        // Mouth / chin.
        path.addCurve(
            to: CGPoint(x: center.x + rect.width * 0.15, y: rect.minY + rect.height * 0.45),
            control1: CGPoint(x: center.x + rect.width * 0.25, y: rect.minY + rect.height * 0.42),
            control2: CGPoint(x: center.x + rect.width * 0.2, y: rect.minY + rect.height * 0.45)
        )
        // Neck.
        path.addLine(to: CGPoint(x: center.x + rect.width * 0.1, y: rect.minY + rect.height * 0.52))
        path.addLine(to: CGPoint(x: center.x - rect.width * 0.15, y: rect.minY + rect.height * 0.52))
        // Back of the head.
        path.addCurve(
            to: CGPoint(x: center.x - rect.width * 0.1, y: rect.minY + rect.height * 0.15),
            control1: CGPoint(x: center.x - rect.width * 0.2, y: rect.minY + rect.height * 0.45),
            control2: CGPoint(x: center.x - rect.width * 0.18, y: rect.minY + rect.height * 0.25)
        )
        path.closeSubpath()

        // Eye.
        path.addEllipse(in: CGRect(
            x: center.x + rect.width * 0.08,
            y: rect.minY + rect.height * 0.22,
            width: rect.width * 0.06,
            height: rect.height * 0.06
        ))

        // Body / neck.
        path.addRect(CGRect(
            x: center.x - rect.width * 0.2,
            y: rect.minY + rect.height * 0.48,
            width: rect.width * 0.4,
            height: rect.height * 0.37
        ))

        // Base.
        path.addRect(CGRect(
            x: center.x - rect.width * 0.3,
            y: rect.maxY - rect.height * 0.15,
            width: rect.width * 0.6,
            height: rect.height * 0.15
        ))

        return path
    }

    private func bishopPath(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // Top point (small circle).
        path.addEllipse(in: CGRect(
            x: center.x - rect.width * 0.08,
            y: rect.minY,
            width: rect.width * 0.16,
            height: rect.height * 0.16
        ))

        // Body (drop shape).
        path.move(to: CGPoint(x: center.x, y: rect.minY + rect.height * 0.16))
        path.addCurve(
            to: CGPoint(x: center.x - rect.width * 0.2, y: rect.maxY - rect.height * 0.2),
            control1: CGPoint(x: center.x - rect.width * 0.25, y: rect.minY + rect.height * 0.4),
            control2: CGPoint(x: center.x - rect.width * 0.25, y: rect.maxY - rect.height * 0.3)
        )
        path.addLine(to: CGPoint(x: center.x + rect.width * 0.2, y: rect.maxY - rect.height * 0.2))
        path.addCurve(
            to: CGPoint(x: center.x, y: rect.minY + rect.height * 0.16),
            control1: CGPoint(x: center.x + rect.width * 0.25, y: rect.maxY - rect.height * 0.3),
            control2: CGPoint(x: center.x + rect.width * 0.25, y: rect.minY + rect.height * 0.4)
        )
        path.closeSubpath()

        // Base.
        path.addRect(CGRect(
            x: center.x - rect.width * 0.3,
            y: rect.maxY - rect.height * 0.2,
            width: rect.width * 0.6,
            height: rect.height * 0.2
        ))

        return path
    }

    private func rookPath(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // Battlements.
        path.move(to: CGPoint(x: center.x - rect.width * 0.25, y: rect.minY))
        path.addLine(to: CGPoint(x: center.x - rect.width * 0.25, y: rect.minY + rect.height * 0.15))
        path.addLine(to: CGPoint(x: center.x - rect.width * 0.1, y: rect.minY + rect.height * 0.15))
        path.addLine(to: CGPoint(x: center.x - rect.width * 0.1, y: rect.minY))
        path.addLine(to: CGPoint(x: center.x + rect.width * 0.1, y: rect.minY))
        path.addLine(to: CGPoint(x: center.x + rect.width * 0.1, y: rect.minY + rect.height * 0.15))
        path.addLine(to: CGPoint(x: center.x + rect.width * 0.25, y: rect.minY + rect.height * 0.15))
        path.addLine(to: CGPoint(x: center.x + rect.width * 0.25, y: rect.minY))
        path.addLine(to: CGPoint(x: center.x + rect.width * 0.3, y: rect.minY))

        // Body.
        path.addLine(to: CGPoint(x: center.x + rect.width * 0.3, y: rect.maxY - rect.height * 0.2))
        path.addLine(to: CGPoint(x: center.x - rect.width * 0.3, y: rect.maxY - rect.height * 0.2))
        path.addLine(to: CGPoint(x: center.x - rect.width * 0.3, y: rect.minY))
        path.closeSubpath()

        // Base.
        path.addRect(CGRect(
            x: center.x - rect.width * 0.35,
            y: rect.maxY - rect.height * 0.2,
            width: rect.width * 0.7,
            height: rect.height * 0.2
        ))

        return path
    }

    private func queenPath(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // Couronne avec 5 pointes arrondies
        // Outer left point
        path.addEllipse(in: CGRect(
            x: center.x - rect.width * 0.3 - rect.width * 0.05,
            y: rect.minY + rect.height * 0.05,
            width: rect.width * 0.1,
            height: rect.height * 0.1
        ))

        // Inner left point
        path.addEllipse(in: CGRect(
            x: center.x - rect.width * 0.15 - rect.width * 0.05,
            y: rect.minY,
            width: rect.width * 0.1,
            height: rect.height * 0.1
        ))

        // Pointe centrale
        path.addEllipse(in: CGRect(
            x: center.x - rect.width * 0.05,
            y: rect.minY - rect.height * 0.02,
            width: rect.width * 0.1,
            height: rect.height * 0.12
        ))

        // Inner right point
        path.addEllipse(in: CGRect(
            x: center.x + rect.width * 0.05,
            y: rect.minY,
            width: rect.width * 0.1,
            height: rect.height * 0.1
        ))

        // Outer right point
        path.addEllipse(in: CGRect(
            x: center.x + rect.width * 0.2,
            y: rect.minY + rect.height * 0.05,
            width: rect.width * 0.1,
            height: rect.height * 0.1
        ))

        // Base de la couronne
        path.addRect(CGRect(
            x: center.x - rect.width * 0.3,
            y: rect.minY + rect.height * 0.15,
            width: rect.width * 0.6,
            height: rect.height * 0.08
        ))

        // Body (an elegant dress-like shape with curves)
        path.move(to: CGPoint(x: center.x - rect.width * 0.25, y: rect.minY + rect.height * 0.23))
        path.addCurve(
            to: CGPoint(x: center.x - rect.width * 0.35, y: rect.maxY - rect.height * 0.2),
            control1: CGPoint(x: center.x - rect.width * 0.15, y: rect.minY + rect.height * 0.4),
            control2: CGPoint(x: center.x - rect.width * 0.25, y: rect.maxY - rect.height * 0.35)
        )
        path.addLine(to: CGPoint(x: center.x + rect.width * 0.35, y: rect.maxY - rect.height * 0.2))
        path.addCurve(
            to: CGPoint(x: center.x + rect.width * 0.25, y: rect.minY + rect.height * 0.23),
            control1: CGPoint(x: center.x + rect.width * 0.25, y: rect.maxY - rect.height * 0.35),
            control2: CGPoint(x: center.x + rect.width * 0.15, y: rect.minY + rect.height * 0.4)
        )
        path.closeSubpath()

        // Base
        path.addRect(CGRect(
            x: center.x - rect.width * 0.4,
            y: rect.maxY - rect.height * 0.2,
            width: rect.width * 0.8,
            height: rect.height * 0.2
        ))

        return path
    }

    private func kingPath(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // Croix
        let crossSize = rect.width * 0.15
        path.addRect(CGRect(
            x: center.x - crossSize * 0.2,
            y: rect.minY,
            width: crossSize * 0.4,
            height: crossSize
        ))
        path.addRect(CGRect(
            x: center.x - crossSize * 0.5,
            y: rect.minY + crossSize * 0.3,
            width: crossSize,
            height: crossSize * 0.4
        ))

        // Couronne
        path.addRect(CGRect(
            x: center.x - rect.width * 0.25,
            y: rect.minY + rect.height * 0.2,
            width: rect.width * 0.5,
            height: rect.height * 0.15
        ))

        // Corps
        path.move(to: CGPoint(x: center.x - rect.width * 0.2, y: rect.minY + rect.height * 0.35))
        path.addLine(to: CGPoint(x: center.x - rect.width * 0.3, y: rect.maxY - rect.height * 0.2))
        path.addLine(to: CGPoint(x: center.x + rect.width * 0.3, y: rect.maxY - rect.height * 0.2))
        path.addLine(to: CGPoint(x: center.x + rect.width * 0.2, y: rect.minY + rect.height * 0.35))
        path.closeSubpath()

        // Base
        path.addRect(CGRect(
            x: center.x - rect.width * 0.35,
            y: rect.maxY - rect.height * 0.2,
            width: rect.width * 0.7,
            height: rect.height * 0.2
        ))

        return path
    }
}
