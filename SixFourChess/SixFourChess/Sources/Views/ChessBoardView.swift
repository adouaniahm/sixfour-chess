import SwiftUI

/// Chessboard view.
struct ChessBoardView: View {
    let board: ChessBoard
    let selectedPosition: Position?
    let availableMoves: [Move]
    let onSquareTapped: (Position) async -> Void
    let isFlipped: Bool
    let animatingMove: Move?
    let onAnimationCompleted: ((Move) -> Void)?
    let accessibilityMode: BoardAccessibilityMode

    // Animation state
    @State private var animatedPiece: Piece?
    @State private var animatedPiecePosition: CGPoint?
    @State private var isAnimatingMove: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let squareSize = min(geometry.size.width, geometry.size.height) / 8
            let boardSize = squareSize * 8
            let rows = Array(0..<8)
            let cols = Array(0..<8)

            ZStack {
                // Board
                VStack(spacing: 0) {
                    ForEach(rows, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(cols, id: \.self) { col in
                                let boardRow = isFlipped ? 7 - row : row
                                let boardCol = isFlipped ? 7 - col : col
                                let position = Position(row: boardRow, col: boardCol)
                                let piece = board.piece(at: position)

                                // Hide piece at source during animation
                                let pieceToShow = isAnimatingMove && position == animatingMove?.from ? nil : piece

                                SquareView(
                                    position: position,
                                    piece: pieceToShow,
                                    isSelected: selectedPosition == position,
                                    isAvailable: availableMoves.contains { $0.to == position },
                                    isLastMove: isLastMoveSquare(row: boardRow, col: boardCol),
                                    isKingInCheck: isKingInCheck(at: position),
                                    squareSize: squareSize,
                                    displayRow: row,
                                    displayCol: col,
                                    isFlipped: isFlipped,
                                    accessibilityMode: accessibilityMode
                                )
                                .onTapGesture {
                                    if !isAnimatingMove {
                                        Task {
                                            await onSquareTapped(Position(row: boardRow, col: boardCol))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(width: boardSize, height: boardSize)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                // Animating piece overlay
                if let piece = animatedPiece, let position = animatedPiecePosition {
                    PieceIconBuilder.piece(type: piece.type, color: piece.color, size: squareSize * 0.65)
                        .position(position)
                }
            }
            .onChange(of: animatingMove) { _, newMove in
                guard let move = newMove else { return }

                // Get the piece before the move is applied
                Logger.debug("Animating move: \(move.piece.type) \(move.from.notation)->\(move.to.notation)", subsystem: .ui)
                animatedPiece = move.piece
                isAnimatingMove = true

                let fromPoint = centerOfSquare(at: move.from, squareSize: squareSize, boardSize: boardSize, geometry: geometry)
                let toPoint = centerOfSquare(at: move.to, squareSize: squareSize, boardSize: boardSize, geometry: geometry)

                animatedPiecePosition = fromPoint

                let duration: Double = reduceMotion ? 0 : 0.3
                withAnimation(reduceMotion ? nil : .easeInOut(duration: duration)) {
                    animatedPiecePosition = toPoint
                }

                // Post-animation cleanup
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    Logger.debug("Animation completed", subsystem: .ui)
                    isAnimatingMove = false
                    animatedPiece = nil
                    animatedPiecePosition = nil
                    onAnimationCompleted?(move)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityIdentifier("chessBoardView")
    }

    private func centerOfSquare(at position: Position, squareSize: CGFloat, boardSize: CGFloat, geometry: GeometryProxy) -> CGPoint {
        let boardOrigin = CGPoint(x: (geometry.size.width - boardSize) / 2, y: (geometry.size.height - boardSize) / 2)

        // Account for flipped board
        let displayCol = isFlipped ? 7 - position.col : position.col
        let displayRow = isFlipped ? 7 - position.row : position.row

        let x = boardOrigin.x + CGFloat(displayCol) * squareSize + squareSize / 2
        let y = boardOrigin.y + CGFloat(displayRow) * squareSize + squareSize / 2
        return CGPoint(x: x, y: y)
    }

    private func isLastMoveSquare(row: Int, col: Int) -> Bool {
        let pos = Position(row: row, col: col)
        return board.lastMove?.from == pos || board.lastMove?.to == pos
    }

    private func isKingInCheck(at position: Position) -> Bool {
        guard let piece = board.piece(at: position),
              piece.type == .king else {
            return false
        }
        return board.isInCheck(color: piece.color)
    }
}

enum BoardAccessibilityMode {
    case interactive
    case readOnly
    case disabled
}

/// View for a single board square.
struct SquareView: View {
    let position: Position
    let piece: Piece?
    let isSelected: Bool
    let isAvailable: Bool
    let isLastMove: Bool
    let isKingInCheck: Bool
    let squareSize: CGFloat
    let displayRow: Int
    let displayCol: Int
    let isFlipped: Bool
    let accessibilityMode: BoardAccessibilityMode

    private var backgroundColor: Color {
        if isSelected {
            return .yellow.opacity(0.6)
        } else if isLastMove {
            return .green.opacity(0.3)
        } else if (position.row + position.col) % 2 == 0 {
            return AppTheme.lightSquareColor
        } else {
            return AppTheme.darkSquareColor
        }
    }

    // MARK: - Accessibility

    private var squareSortPriority: Double {
        let index = isFlipped
            ? position.row * 8 + (7 - position.col)
            : (7 - position.row) * 8 + position.col
        return Double(index)
    }

    private var squareAccessibilityLabel: String {
        var parts: [String] = []

        // Position
        parts.append("a11y.square".localized(with: position.notation))

        // Piece or empty square.
        if let piece = piece {
            let colorText = piece.color == .white ? "color.white".localized : "color.black".localized
            let pieceText: String
            switch piece.type {
            case .pawn: pieceText = "piece.pawn".localized
            case .knight: pieceText = "piece.knight".localized
            case .bishop: pieceText = "piece.bishop".localized
            case .rook: pieceText = "piece.rook".localized
            case .queen: pieceText = "piece.queen".localized
            case .king: pieceText = "piece.king".localized
            }
            parts.append("\(colorText) \(pieceText)")
        } else {
            parts.append("a11y.emptySquare".localized)
        }

        return parts.joined(separator: ", ")
    }

    private var squareAccessibilityValue: String {
        var parts: [String] = []

        if isSelected {
            parts.append("a11y.selected".localized)
        }

        if isAvailable {
            parts.append("a11y.availableMove".localized)
        }

        if isLastMove {
            parts.append("a11y.lastMove".localized)
        }

        return parts.isEmpty ? "" : parts.joined(separator: ", ")
    }

    private var squareAccessibilityHint: String {
        switch accessibilityMode {
        case .interactive:
            break
        case .readOnly:
            return "a11y.hint.readOnlyBoard".localized
        case .disabled:
            return "a11y.hint.gameOverBoard".localized
        }

        if piece != nil {
            return "a11y.hint.tapToSelect".localized
        } else if isAvailable {
            return "a11y.hint.tapToMove".localized
        } else {
            return ""
        }
    }

    private var accessibilityTraits: AccessibilityTraits {
        switch accessibilityMode {
        case .interactive:
            return piece != nil || isAvailable ? .isButton : []
        case .readOnly, .disabled:
            return .isStaticText
        }
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(backgroundColor)

            // Border for the selected square, not just a color change.
            if isSelected {
                Rectangle()
                    .strokeBorder(Color.blue, lineWidth: 3)
            }

            // Border for the last move, not just a color change.
            if isLastMove && !isSelected {
                Rectangle()
                    .strokeBorder(Color.green, lineWidth: 2)
            }

            if let piece = piece {
                PieceIconBuilder.piece(type: piece.type, color: piece.color, size: squareSize * 0.65)
                    .shadow(color: isKingInCheck ? .red : .clear, radius: isKingInCheck ? 15 : 0)
                    .shadow(color: isKingInCheck ? .red.opacity(0.8) : .clear, radius: isKingInCheck ? 10 : 0)
                    .shadow(color: isKingInCheck ? .red.opacity(0.6) : .clear, radius: isKingInCheck ? 5 : 0)
                    .accessibilityHidden(true) // The visual shape is hidden; the label is on the parent.
            }

            if isAvailable {
                Circle()
                    .fill(Color.green.opacity(0.5))
                    .frame(width: squareSize * 0.3, height: squareSize * 0.3)
                    .accessibilityHidden(true) // Already covered by the label.
            }

            // Coordinates (a-h, 1-8).
            if position.row == 7 {
                let fileIndex = isFlipped ? displayCol : position.col
                Text(String("abcdefgh"["abcdefgh".index("abcdefgh".startIndex, offsetBy: fileIndex)]))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor((position.row + position.col) % 2 == 0 ? .brown : .white.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(2)
                    .accessibilityHidden(true) // Already covered by the label.
            }

            if position.col == 0 {
                let rankValue = isFlipped ? displayRow + 1 : 8 - position.row
                Text("\(rankValue)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor((position.row + position.col) % 2 == 0 ? .brown : .white.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(2)
                    .accessibilityHidden(true) // Already covered by the label.
            }
        }
        .frame(width: squareSize, height: squareSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(squareAccessibilityLabel)
        .accessibilityValue(squareAccessibilityValue)
        .accessibilityHint(squareAccessibilityHint)
        .accessibilityAddTraits(accessibilityTraits)
        .accessibilitySortPriority(squareSortPriority)
    }
}

// `ChessPieceShape` was extracted into `Sources/Views/ChessPieceShape.swift`.
