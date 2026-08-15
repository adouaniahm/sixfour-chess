//
//  MoveCommentToastView.swift
//  SixFourChess
//
//  Move analysis toast. Displayed as an overlay on the board after each move.
//  Styling is consistent with the existing ToastView.
//

import SwiftUI

struct MoveCommentToastView: View {
    let comment: MoveComment
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: comment.icon)
                .foregroundColor(accentColor)
                .font(.system(size: 16, weight: .semibold))
                .accessibilityHidden(true)

            Text(comment.message)
                .font(.system(.subheadline, design: .serif)).fontWeight(.medium)
                .foregroundColor(AppTheme.primaryTextColor(for: colorScheme))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            AppTheme.cardBackgroundColor(for: colorScheme)
                .shadow(color: Color.black.opacity(0.2), radius: 16, y: 4)
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(accentColor.opacity(0.5), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .onAppear {
            AccessibilityService.shared.enqueue(comment.message)
        }
    }

    private var accentColor: Color {
        Color(hex: comment.accentColor) ?? AppTheme.accentColor(for: colorScheme)
    }
}

// MARK: - Color hex init

private extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6,
              let value = UInt64(hex, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
