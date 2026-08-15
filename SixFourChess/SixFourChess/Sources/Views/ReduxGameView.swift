//
//  ReduxGameView.swift
//  SixFourChess
//

import SwiftUI
import UIKit

private struct AppReduxStoreFocusedValueKey: FocusedValueKey {
    typealias Value = AppReduxStore
}

extension FocusedValues {
    var appReduxStore: AppReduxStore? {
        get { self[AppReduxStoreFocusedValueKey.self] }
        set { self[AppReduxStoreFocusedValueKey.self] = newValue }
    }
}

struct ReduxGameView: View {
    @Environment(\.appReduxStore) private var appStore
    @Environment(\.colorScheme) private var colorScheme

    private var activeAlertBinding: Binding<GameAlert?> {
        Binding(
            get: { appStore.state.uiState.activeAlert },
            set: { if $0 == nil { appStore.dispatch(AppAction.ui(.dismissAlert)) } }
        )
    }

    private var activeSheetBinding: Binding<ActiveSheet?> {
        Binding(
            get: { appStore.state.uiState.activeSheet },
            set: { if $0 == nil { appStore.dispatch(AppAction.ui(.dismissSheet)) } }
        )
    }

    var body: some View {
        let gameState = appStore.state.gameState
        let uiState = appStore.state.uiState

        NavigationStack {
            ZStack {
                GameBackgroundView()

                gameContentView(gameState: gameState, uiState: uiState)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            VStack(spacing: 1) {
                                Text("home.title".localized)
                                    .font(.system(size: 20, weight: .bold, design: .serif))

                                Text("home.subtitle".localized)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(1.3)
                            }
                            .multilineTextAlignment(.center)
                        }

                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink {
                                ReduxSettingsView()
                            } label: {
                                Image(systemName: "gear")
                            }
                            .accessibilityIdentifier("settingsButton")
                            .accessibilityLabel("a11y.toolbar.settings".localized)
                        }
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(.clear, for: .navigationBar)
        }
        .sheet(item: activeSheetBinding) { sheet in
            switch sheet {
            case .hint:
                HintSheetView(
                    hintText: uiState.currentHint,
                    suggestedMove: gameState.suggestedMove,
                    hintsRemaining: gameState.hintsRemaining,
                    onPlayMove: {
                        if let suggestedMove = gameState.suggestedMove {
                            Task {
                                await handleSquareTapped(suggestedMove.from)
                                try? await Task.sleep(nanoseconds: 50_000_000)
                                await handleSquareTapped(suggestedMove.to)
                            }
                        }
                        appStore.dispatch(AppAction.ui(.setHintAlert(hint: "")))
                    }
                )
            case .history:
                CurrentGameHistoryView(moveHistory: gameState.board.moveHistory)
            }
        }
        .alert(
            alertTitle(for: uiState.activeAlert),
            isPresented: .init(
                get: { uiState.activeAlert != nil && uiState.activeAlert != .promotion },
                set: { if !$0 { appStore.dispatch(AppAction.ui(.dismissAlert)) } }
            )
        ) {
            alertActions(for: uiState.activeAlert, gameState: gameState, uiState: uiState)
        } message: {
            alertMessage(for: uiState.activeAlert, gameState: gameState, uiState: uiState)
        }
        .focusedSceneValue(\.appReduxStore, appStore)
        .onChange(of: gameState.gameResult) { _, newValue in
            guard newValue != nil else { return }
            appStore.dispatch(AppAction.ui(.showAlert(.gameResult)))
        }
    }

    private func alertTitle(for alert: GameAlert?) -> String {
        guard let alert else { return "" }
        switch alert {
        case .gameResult:
            return "game.result.title".localized
        case .promotion:
            return ""
        case .aiPromotion:
            return "promotion.aiTitle".localized
        case .error:
            return appStore.state.uiState.errorAlertTitle
        case .newGameConfirmation:
            return "alert.newGame.title".localized
        }
    }

    @ViewBuilder
    private func alertActions(for alert: GameAlert?, gameState: GameState, uiState: UIState) -> some View {
        switch alert {
        case .gameResult:
            Button("action.newGame".localized) {
                appStore.dispatch(AppAction.game(.resetGame))
            }
            Button("action.ok".localized, role: .cancel) {}

        case .promotion:
            EmptyView()

        case .aiPromotion:
            Button("action.ok".localized) {
                if let move = uiState.aiPromotionMove {
                    appStore.dispatch(AppAction.ui(.setAIPromotionAlert(pieceType: nil, move: nil)))
                    appStore.dispatch(AppAction.ui(.animateMove(move: move)))
                }
            }

        case .error:
            Button("action.ok".localized, role: .cancel) {
                appStore.dispatch(AppAction.ui(.setErrorAlert(title: "", message: "")))
            }

        case .newGameConfirmation:
            Button("action.cancel".localized, role: .cancel) {}
            Button("action.newGame".localized, role: .destructive) {
                appStore.dispatch(AppAction.game(.resetGame))
            }

        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private func alertMessage(for alert: GameAlert?, gameState: GameState, uiState: UIState) -> some View {
        switch alert {
        case .gameResult:
            Text(gameState.gameResult?.description ?? "")
        case .promotion:
            EmptyView()
        case .aiPromotion:
            if let pieceType = uiState.aiPromotionPieceType {
                Text("promotion.aiMessage".localized(with: pieceType.localizedName))
            }
        case .error:
            Text(uiState.errorAlertMessage)
        case .newGameConfirmation:
            Text("alert.newGame.message".localized)
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private func gameContentView(gameState: GameState, uiState: UIState) -> some View {
        let flipBoard = shouldFlipBoard(gameState: gameState)
        let topColor: PieceColor = flipBoard ? .white : .black
        let bottomColor: PieceColor = flipBoard ? .black : .white

        GeometryReader { geometry in
            let contentWidth = min(geometry.size.width - 28, 760)
            let boardWidth = min(contentWidth, UIDevice.current.userInterfaceIdiom == .pad ? 620 : geometry.size.width - 32)

            VStack(spacing: 0) {
                Spacer(minLength: 8)

                VStack(spacing: 14) {
                    playerInfoSection(color: topColor, gameState: gameState)
                        .frame(maxWidth: contentWidth)
                        .accessibilitySortPriority(2)

                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.cardBackgroundColor(for: colorScheme).opacity(colorScheme == .dark ? 0.20 : 0.24))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.black.opacity(colorScheme == .dark ? 0.18 : 0.08), lineWidth: 1)
                            }
                            .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.08), radius: 10, y: 5)

                        VStack(spacing: 0) {
                            ZStack {
                                ChessBoardView(
                                    board: gameState.board,
                                    selectedPosition: gameState.selectedPosition,
                                    availableMoves: gameState.availableMoves,
                                    onSquareTapped: { position in
                                        await handleSquareTapped(position)
                                    },
                                    isFlipped: flipBoard,
                                    animatingMove: uiState.animatingMove,
                                    onAnimationCompleted: { move in
                                        appStore.dispatch(AppAction.game(.makeMove(move: move)))
                                        appStore.dispatch(AppAction.ui(.completeAnimatedMove))
                                    },
                                    accessibilityMode: gameState.gameResult == nil ? .interactive : .disabled
                                )

                                if uiState.showCloudError {
                                    cloudErrorOverlay(isNetwork: uiState.cloudErrorIsNetwork)
                                }

                                if uiState.activeAlert == .promotion {
                                    promotionPickerOverlay(color: gameState.board.currentPlayer)
                                }
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .padding(5)
                    }
                    .frame(width: boardWidth)
                    .allowsHitTesting(gameState.gameResult == nil)
                    .opacity(gameState.gameResult == nil ? 1 : 0.92)
                    .accessibilitySortPriority(1)

                    playerInfoSection(color: bottomColor, gameState: gameState)
                        .frame(maxWidth: contentWidth)
                        .accessibilitySortPriority(0)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 10)

                GameControlBar()
                    .frame(maxWidth: contentWidth)
                    .accessibilitySortPriority(-1)
                    .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .overlay(alignment: .bottom) {
            if let comment = uiState.currentMoveComment {
                MoveCommentToastView(comment: comment)
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(duration: 0.35), value: comment)
            }
        }
        .onAppear {
            if UIAccessibility.isVoiceOverRunning {
                AccessibilityService.shared.cancelAll()
                AccessibilityService.shared.announceGameSummary(gameState: gameState)
            }
        }
    }

    @ViewBuilder
    private func playerInfoSection(color: PieceColor, gameState: GameState) -> some View {
        PlayerInfoView(
            color: color,
            capturedPieces: GameSelectors.capturedPieces(for: color, state: gameState),
            isCurrentPlayer: GameSelectors.isCurrentPlayer(color, state: gameState),
            isThinking: gameState.isThinking && gameState.board.currentPlayer == color,
            isBot: GameSelectors.isAI(color, state: gameState),
            playerName: nil
        )
    }

    private func shouldFlipBoard(gameState: GameState) -> Bool {
        gameState.gameMode == .playerVsAI && gameState.whiteAIEnabled && !gameState.blackAIEnabled
    }

    @MainActor
    private func handleSquareTapped(_ position: Position) async {
        let gameState = appStore.state.gameState

        guard gameState.gameResult == nil else {
            AccessibilityService.shared.enqueue("a11y.announce.gameOver".localized)
            return
        }

        guard !gameState.isThinking else {
            AccessibilityService.shared.enqueue("a11y.announce.aiThinking".localized)
            return
        }

        guard !gameState.isCurrentPlayerAI else {
            AccessibilityService.shared.enqueue("a11y.announce.aiThinking".localized)
            return
        }

        guard gameState.canCurrentPlayerMove else {
            return
        }

        if let selectedPos = gameState.selectedPosition {
            if let move = GameSelectors.move(to: position, state: gameState) {
                if move.promotionType != nil {
                    let promotionMoves = generatePromotionMoves(for: move)
                    appStore.dispatch(AppAction.ui(.setPromotionAlert(moves: promotionMoves)))
                } else {
                    appStore.dispatch(AppAction.game(.deselectSquare))
                    appStore.dispatch(AppAction.ui(.animateMove(move: move)))
                }
            } else if position == selectedPos {
                appStore.dispatch(AppAction.game(.deselectSquare))
                AccessibilityService.shared.enqueue("a11y.announce.deselected".localized)
            } else if let piece = gameState.board.piece(at: position),
                      piece.color == gameState.board.currentPlayer {
                appStore.dispatch(AppAction.game(.selectSquare(position: position)))
            } else {
                appStore.dispatch(AppAction.game(.deselectSquare))
            }
        } else if let piece = gameState.board.piece(at: position),
                  piece.color == gameState.board.currentPlayer {
            appStore.dispatch(AppAction.game(.selectSquare(position: position)))
        }
    }

    private func generatePromotionMoves(for move: Move) -> [Move] {
        [PieceType.queen, .rook, .bishop, .knight].map { type in
            Move(
                from: move.from,
                to: move.to,
                piece: move.piece,
                capturedPiece: move.capturedPiece,
                promotionType: type
            )
        }
    }

    @ViewBuilder
    private func promotionPickerOverlay(color: PieceColor) -> some View {
        let options = UISelectors.promotionOptions(state: appStore.state.uiState)
        ZStack {
            Color.black.opacity(0.35)
                .onTapGesture {}

            VStack(spacing: 12) {
                Text("promotion.title".localized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 16) {
                    ForEach(options, id: \.self) { pieceType in
                        Button {
                            appStore.dispatch(AppAction.game(.promotePawn(to: pieceType)))
                        } label: {
                            VStack(spacing: 6) {
                                PieceIconBuilder.piece(type: pieceType, color: color, size: 44)
                                Text(pieceType.localizedName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                            .frame(width: 64)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.2), radius: 12)
        }
    }

    @ViewBuilder
    private func cloudErrorOverlay(isNetwork: Bool) -> some View {
        VStack(spacing: 16) {
            Image(systemName: isNetwork ? "wifi.slash" : "exclamationmark.icloud")
                .font(.system(size: 36))
                .foregroundColor(.white)

            Text("cloud.error.title".localized)
                .font(.headline)
                .foregroundColor(.white)

            Text(isNetwork ? "cloud.error.network".localized : "cloud.error.api".localized)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)

            Text("cloud.error.suggestion".localized)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Button {
                appStore.dispatch(AppAction.game(.retryCloudAI))
            } label: {
                Label("cloud.error.retry".localized, systemImage: "arrow.clockwise")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.2), in: Capsule())
                    .foregroundColor(.white)
            }
        }
        .padding(24)
        .frame(maxWidth: 300)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 12)
    }

    private var adaptiveSpacing: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 12 : 8
    }
}
