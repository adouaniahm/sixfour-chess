//
//  ReduxSettingsView.swift
//  SixFourChess
//
//  Redux Settings View
//

import SwiftUI

/// Settings view backed by Redux state.
struct ReduxSettingsView: View {
    @Environment(\.appReduxStore) private var appStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedMode: GameMode
    @State private var selectedDifficulty: AIDifficulty
    @State private var soundEnabled: Bool
    @State private var moveCommentsEnabled: Bool
    @State private var showConsentBanner = false
    @State private var showDifficultyLockedAlert = false

    init() {
        let gameState = AppReduxStore.shared.state.gameState
        _selectedMode = State(initialValue: gameState.gameMode.normalizedForCurrentRelease)
        _selectedDifficulty = State(initialValue: gameState.difficulty)
        _soundEnabled = State(initialValue: UserSettingsStorage.shared.loadSoundEnabled())
        _moveCommentsEnabled = State(initialValue: UserSettingsStorage.shared.loadMoveCommentsEnabled())
    }

    var body: some View {
        Form {
            settingsContent
        }
        .accessibilityIdentifier("settingsView")
        .navigationTitle("settings.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let gameState = appStore.state.gameState
            selectedMode = gameState.gameMode.normalizedForCurrentRelease
            selectedDifficulty = gameState.difficulty
            soundEnabled = UserSettingsStorage.shared.loadSoundEnabled()
            moveCommentsEnabled = UserSettingsStorage.shared.loadMoveCommentsEnabled()
        }
        .onChange(of: selectedDifficulty) { _, newDifficulty in
            applyDifficultyChange(to: newDifficulty)
        }
        .sheet(isPresented: $showConsentBanner) {
            ConsentModule.makeSimpleConsentBannerView(
                onConsentGiven: {
                    Logger.success("Consent updated", subsystem: .consent)
                    showConsentBanner = false
                },
                onConsentDenied: {
                    showConsentBanner = false
                }
            )
        }
        .alert("settings.difficulty.locked.title".localized, isPresented: $showDifficultyLockedAlert) {
            Button("action.ok".localized, role: .cancel) {}
        } message: {
            Text("settings.difficulty.locked.message".localized)
        }
    }

    @ViewBuilder
    private var settingsContent: some View {
        let gameState = appStore.state.gameState
        let isDifficultyLocked = !gameState.board.moveHistory.isEmpty && gameState.gameResult == nil

        Section("settings.gameMode".localized) {
            GameModeSummaryCard(
                mode: selectedMode,
                difficulty: selectedDifficulty,
                colorScheme: colorScheme
            )
        }

        Section {
            ForEach(AIDifficulty.allCases, id: \.self) { difficulty in
                DifficultyRow(
                    difficulty: difficulty,
                    isSelected: selectedDifficulty == difficulty,
                    colorScheme: colorScheme
                ) {
                    guard !isDifficultyLocked else {
                        showDifficultyLockedAlert = true
                        return
                    }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDifficulty = difficulty
                    }
                }
            }
        } header: {
            Text("settings.difficulty".localized)
        }

        Section("ui.history".localized) {
            NavigationLink {
                PlayedGamesHistoryView()
            } label: {
                Label("history.played.title".localized, systemImage: "clock.arrow.circlepath")
            }
            .accessibilityIdentifier("playedGamesHistoryLink")
        }

        Section("settings.feedback".localized) {
            Toggle("settings.soundEffects".localized, isOn: $soundEnabled)
                .onChange(of: soundEnabled) { _, newValue in
                    UserSettingsStorage.shared.saveSoundEnabled(newValue)
                }

            Toggle("settings.moveComments".localized, isOn: $moveCommentsEnabled)
                .onChange(of: moveCommentsEnabled) { _, newValue in
                    UserSettingsStorage.shared.saveMoveCommentsEnabled(newValue)
                }
        }

        Section {
            Button {
                showConsentBanner = true
            } label: {
                Label("consent.settings.preferences".localized, systemImage: "hand.raised.fill")
            }

            NavigationLink {
                PrivacyPolicyView()
            } label: {
                Label("settings.privacy".localized, systemImage: "doc.text.fill")
            }
        } header: {
            Text("privacy.title".localized)
        }

        Section("settings.about".localized) {
            HStack {
                Label("settings.version".localized, systemImage: "info.circle")
                Spacer()
                Text(AppVersion.displayString)
                    .foregroundColor(.secondary)
            }

            NavigationLink {
                TechStackView()
            } label: {
                Label("settings.info".localized, systemImage: "cpu")
            }

            Link(destination: URL(string: "https://github.com/adouaniahm/six-four-chess/issues")!) {
                HStack {
                    Label("settings.support".localized, systemImage: "envelope")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("settings.copyright".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("settings.allRightsReserved".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    /// Applies the difficulty change immediately.
    private func applyDifficultyChange(to newDifficulty: AIDifficulty) {
        guard newDifficulty != appStore.state.gameState.difficulty else { return }
        appStore.dispatch(AppAction.game(.changeDifficulty(difficulty: newDifficulty)))
    }
}

// MARK: - Game Mode Summary

/// Static summary card for the current game mode.
private struct GameModeSummaryCard: View {
    let mode: GameMode
    let difficulty: AIDifficulty
    let colorScheme: ColorScheme

    private var modeSummaryText: String {
        difficulty == .master
            ? "settings.gameMode.masterModeSummary".localized
            : "settings.gameMode.singleMode".localized
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(mode.accentColor.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: mode.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(mode.accentColor)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(mode.localizedName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.primaryTextColor(for: colorScheme))

                Text(modeSummaryText)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryTextColor(for: colorScheme))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mode.localizedName)
        .accessibilityValue(modeSummaryText)
    }
}

// MARK: - Difficulty Row

/// Difficulty selection row.
private struct DifficultyRow: View {
    let difficulty: AIDifficulty
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: difficulty.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(difficulty.accentColor)
                    .frame(width: 28)
                    .accessibilityHidden(true)

                // Name
                Text(difficulty.localizedName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(
                        isSelected
                            ? AppTheme.primaryTextColor(for: colorScheme)
                            : AppTheme.secondaryTextColor(for: colorScheme)
                    )

                Spacer()

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(
                        isSelected
                            ? difficulty.accentColor
                            : .secondary.opacity(0.4)
                    )
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(difficulty.localizedName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
