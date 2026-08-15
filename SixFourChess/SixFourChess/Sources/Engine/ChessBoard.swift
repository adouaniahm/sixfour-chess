import Foundation
import Observation

/// Represents the current board state.
@Observable
final class ChessBoard {
    var state: ChessState

    // MARK: - Forwarding Properties
    
    var board: [[Piece?]] {
        get { state.board }
        set { state.board = newValue }
    }
    
    var currentPlayer: PieceColor {
        get { state.currentPlayer }
        set { state.currentPlayer = newValue }
    }
    
    var moveHistory: [String] {
        get { state.moveHistory }
        set { state.moveHistory = newValue }
    }
    
    var moveHistoryDetailed: [Move] {
        get { state.moveHistoryDetailed }
        set { state.moveHistoryDetailed = newValue }
    }
    
    var capturedPieces: [Piece] {
        get { state.capturedPieces }
        set { state.capturedPieces = newValue }
    }
    
    var lastMove: Move? {
        get { state.lastMove }
        set { state.lastMove = newValue }
    }
    
    var enPassantTarget: Position? {
        get { state.enPassantTarget }
        set { state.enPassantTarget = newValue }
    }
    
    var isWhiteKingMoved: Bool {
        get { state.isWhiteKingMoved }
        set { state.isWhiteKingMoved = newValue }
    }
    
    var isBlackKingMoved: Bool {
        get { state.isBlackKingMoved }
        set { state.isBlackKingMoved = newValue }
    }
    
    var isWhiteRookLeftMoved: Bool {
        get { state.isWhiteRookLeftMoved }
        set { state.isWhiteRookLeftMoved = newValue }
    }
    
    var isWhiteRookRightMoved: Bool {
        get { state.isWhiteRookRightMoved }
        set { state.isWhiteRookRightMoved = newValue }
    }
    
    var isBlackRookLeftMoved: Bool {
        get { state.isBlackRookLeftMoved }
        set { state.isBlackRookLeftMoved = newValue }
    }
    
    var isBlackRookRightMoved: Bool {
        get { state.isBlackRookRightMoved }
        set { state.isBlackRookRightMoved = newValue }
    }
    
    var halfMoveClock: Int {
        get { state.halfMoveClock }
        set { state.halfMoveClock = newValue }
    }
    
    var fullMoveNumber: Int {
        get { state.fullMoveNumber }
        set { state.fullMoveNumber = newValue }
    }

    // MARK: - Initialization

    init() {
        self.state = ChessState()
    }

    init(state: ChessState) {
        self.state = state
    }

    convenience init(
        board: [[Piece?]],
        currentPlayer: PieceColor,
        moveHistory: [String],
        moveHistoryDetailed: [Move],
        capturedPieces: [Piece],
        lastMove: Move?,
        enPassantTarget: Position?,
        isWhiteKingMoved: Bool,
        isBlackKingMoved: Bool,
        isWhiteRookLeftMoved: Bool,
        isWhiteRookRightMoved: Bool,
        isBlackRookLeftMoved: Bool,
        isBlackRookRightMoved: Bool,
        halfMoveClock: Int,
        fullMoveNumber: Int
    ) {
        var newState = ChessState()
        newState.board = board
        newState.currentPlayer = currentPlayer
        newState.moveHistory = moveHistory
        newState.moveHistoryDetailed = moveHistoryDetailed
        newState.capturedPieces = capturedPieces
        newState.lastMove = lastMove
        newState.enPassantTarget = enPassantTarget
        newState.isWhiteKingMoved = isWhiteKingMoved
        newState.isBlackKingMoved = isBlackKingMoved
        newState.isWhiteRookLeftMoved = isWhiteRookLeftMoved
        newState.isWhiteRookRightMoved = isWhiteRookRightMoved
        newState.isBlackRookLeftMoved = isBlackRookLeftMoved
        newState.isBlackRookRightMoved = isBlackRookRightMoved
        newState.halfMoveClock = halfMoveClock
        newState.fullMoveNumber = fullMoveNumber
        
        self.init(state: newState)
    }

    // MARK: - Access

    func piece(at position: Position) -> Piece? {
        state.piece(at: position)
    }

    func setPiece(_ piece: Piece?, at position: Position) {
        state.setPiece(piece, at: position)
    }

    // MARK: - Game State

    func kingPosition(for color: PieceColor) -> Position? {
        state.kingPosition(for: color)
    }

    func isInCheck(color: PieceColor) -> Bool {
        state.isInCheck(color: color)
    }

    func isCheckmate(for color: PieceColor) -> Bool {
        state.isCheckmate(for: color)
    }

    func isStalemate(for color: PieceColor) -> Bool {
        state.isStalemate(for: color)
    }

    func getAllLegalMoves(for color: PieceColor) -> [Move] {
        state.getAllLegalMoves(for: color)
    }

    // MARK: - Move Execution

    @discardableResult
    func makeMove(_ move: Move) -> Bool {
        state.makeMove(move)
    }

    func undoLastMove() {
        state.undoLastMove()
    }

    // MARK: - Draw Rules

    func isFiftyMoveRule() -> Bool {
        state.isFiftyMoveRule()
    }

    func isThreefoldRepetition() -> Bool {
        state.isThreefoldRepetition()
    }

    // MARK: - Factory Methods

    static func fromMoveHistory(_ moves: [String]) throws -> ChessBoard {
        let board = ChessBoard()
        
        for (index, algebraic) in moves.enumerated() {
            // Note: AlgebraicNotationParser.parseMove depends on ChessBoard methods
            // board has state, so its methods work.
            guard let move = AlgebraicNotationParser.parseMove(algebraic, on: board) else {
                throw ChessError.invalidMove("Invalid algebraic notation at move \(index + 1): \(algebraic)")
            }

            guard board.makeMove(move) else {
                throw ChessError.invalidMove("Illegal move at \(index + 1): \(algebraic)")
            }
        }

        return board
    }

    // MARK: - Copy

    func copy() -> ChessBoard {
        // Create a new ChessBoard with a COPY of the state struct
        return ChessBoard(state: self.state)
    }
}
