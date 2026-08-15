//
//  TechStackSection.swift
//  SixFourChess
//
//  "Information" screen - displays the app's technical stack.
//

import SwiftUI

/// Dedicated technical stack screen, reachable from settings.
struct TechStackView: View {
    var body: some View {
        List {
            // Architecture
            Section {
                TechItem("tech.architecture.redux".localized)
                TechItem("tech.architecture.middleware".localized)
                TechItem("tech.architecture.flow".localized)
            } header: {
                TechSectionHeader(
                    icon: "building.columns.fill",
                    title: "tech.architecture".localized,
                    color: .purple
                )
            }

            // AI engine
            Section {
                TechItem("tech.ai.elo".localized)
                TechItem("tech.ai.elo.master".localized)
                TechItem("tech.ai.nnue".localized)
                TechItem("tech.ai.minimax".localized)
                TechItem("tech.ai.nullmove".localized)
                TechItem("tech.ai.quiescence".localized)
                TechItem("tech.ai.lmr".localized)
                TechItem("tech.ai.killer".localized)
                TechItem("tech.ai.check_ext".localized)
                TechItem("tech.ai.evaluation".localized)
                TechItem("tech.ai.mvvlva".localized)
                TechItem("tech.ai.transposition".localized)
                TechItem("tech.ai.opening_book".localized)
            } header: {
                TechSectionHeader(
                    icon: "brain.fill",
                    title: "tech.ai".localized,
                    color: .orange
                )
            }

            // Frameworks
            Section {
                TechItem("tech.frameworks.swift6".localized)
                TechItem("tech.frameworks.swiftui".localized)
                TechItem("tech.frameworks.concurrency".localized)
                TechItem("tech.frameworks.swiftdata".localized)
            } header: {
                TechSectionHeader(
                    icon: "swift",
                    title: "tech.frameworks".localized,
                    color: .red
                )
            }

            // Accessibility
            Section {
                TechItem("tech.accessibility.voiceover".localized)
                TechItem("tech.accessibility.haptics".localized)
                TechItem("tech.accessibility.i18n".localized)
            } header: {
                TechSectionHeader(
                    icon: "accessibility.fill",
                    title: "tech.accessibility".localized,
                    color: .green
                )
            }
        }
        .navigationTitle("settings.info".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Supporting Views

private struct TechSectionHeader: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        Label(title, systemImage: icon)
            .foregroundStyle(color)
            .textCase(nil)
    }
}

private struct TechItem: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.subheadline)
    }
}

#Preview {
    NavigationStack {
        TechStackView()
    }
}
