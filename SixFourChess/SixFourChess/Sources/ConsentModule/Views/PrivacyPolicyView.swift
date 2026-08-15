import SwiftUI

/// Privacy policy view.
/// Shows a summary and a link to the full policy hosted on GitHub Pages.
struct PrivacyPolicyView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    // Privacy policy URL hosted on GitHub Pages (v2).
    private var privacyPolicyURL: URL {
        let baseURL = "https://adouaniahm.github.io/six-four-chess-site/privacy/v2.3/"
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        switch languageCode {
        case "fr":
            return URL(string: baseURL + "privacy-fr.html")!
        case "it":
            return URL(string: baseURL + "privacy-it.html")!
        default:
            return URL(string: baseURL)!
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with icon.
                HStack(spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .font(.title)
                        .foregroundStyle(accentColor)
                        .accessibilityHidden(true)

                    Text("privacy.policy.title")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(primaryTextColor)
                }

                // Short summary.
                summarySection

                Divider()
                    .background(secondaryTextColor.opacity(0.3))

                // Key points.
                keyPointsSection

                Divider()
                    .background(secondaryTextColor.opacity(0.3))

                // Button linking to the full policy.
                fullPolicyButton

                // Contact information.
                contactSection
            }
            .padding()
        }
        .background(backgroundColor)
        .navigationTitle("privacy.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Colors (using centralized AppTheme)

    private var backgroundColor: Color {
        AppTheme.backgroundColor(for: colorScheme)
    }

    private var primaryTextColor: Color {
        AppTheme.primaryTextColor(for: colorScheme)
    }

    private var secondaryTextColor: Color {
        AppTheme.secondaryTextColor(for: colorScheme)
    }

    private var accentColor: Color {
        AppTheme.accentColor(for: colorScheme)
    }

    private var cardBackgroundColor: Color {
        AppTheme.cardBackgroundColor(for: colorScheme)
    }

    // MARK: - Sections

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("privacy.policy.summary.title")
                .font(.headline)
                .foregroundStyle(primaryTextColor)

            Text("privacy.policy.summary.content")
                .font(.subheadline)
                .foregroundStyle(secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var keyPointsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("privacy.policy.key.points")
                .font(.headline)
                .foregroundStyle(primaryTextColor)

            KeyPointRow(
                icon: "checkmark.shield.fill",
                text: "privacy.policy.point.offline",
                color: .green
            )

            KeyPointRow(
                icon: "network",
                text: "privacy.policy.point.cloudai",
                color: .blue
            )

            KeyPointRow(
                icon: "hand.raised.fill",
                text: "privacy.policy.point.consent",
                color: accentColor
            )

            KeyPointRow(
                icon: "eye.slash.fill",
                text: "privacy.policy.point.no.ads",
                color: .orange
            )

            KeyPointRow(
                icon: "checkmark.seal.fill",
                text: "privacy.policy.point.gdpr",
                color: .purple
            )
        }
    }

    private var fullPolicyButton: some View {
        Button {
            openURL(privacyPolicyURL)
        } label: {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.title3)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("privacy.policy.read.full")
                        .font(.system(.body, weight: .semibold))

                    Text("privacy.policy.external.link")
                        .font(.caption)
                        .foregroundStyle(secondaryTextColor)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square.fill")
                    .font(.title2)
                    .accessibilityHidden(true)
            }
            .padding()
            .background(cardBackgroundColor)
            .foregroundStyle(accentColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accentColor.opacity(0.3), lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("privacy.policy.contact.title")
                .font(.headline)
                .foregroundStyle(primaryTextColor)

            VStack(alignment: .leading, spacing: 8) {
                ContactRow(icon: "building.2.fill", text: "ADOUANI SAS")
                ContactRow(icon: "envelope.fill", text: "adouani.sas@gmail.com")
            }
            .font(.subheadline)
            .foregroundStyle(secondaryTextColor)
        }
    }
}

// MARK: - Supporting Views

struct KeyPointRow: View {
    let icon: String
    let text: String
    let color: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(LocalizedStringKey(text))
                .font(.subheadline)
                .foregroundStyle(AppTheme.primaryTextColor(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ContactRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(text)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
