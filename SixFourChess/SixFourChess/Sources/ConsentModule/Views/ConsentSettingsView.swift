import SwiftUI

/// Simplified consent settings view (OneTrust-style).
struct ConsentSettingsView: View {

    // MARK: - Properties

    var manager: ConsentManagerProtocol

    // MARK: - State

    @Environment(\.appReduxStore) private var appStore
    @State private var showConsentBanner = false
    @State private var showComingSoonAlert = false
    @State private var comingSoonMessage = ""

    // MARK: - Body

    var body: some View {
        List {
            // Status section.
            statusSection

            // Privacy categories section.
            categoriesSection

            // Actions section.
            actionsSection
        }
        .navigationTitle("consent.settings.title")
        .sheet(isPresented: $showConsentBanner) {
            ConsentModule.makeSimpleConsentBannerView(
                onConsentGiven: {
                    showConsentBanner = false
                },
                onConsentDenied: {
                    showConsentBanner = false
                }
            )
        }
        .alert("consent.settings.comingsoon.title", isPresented: $showComingSoonAlert) {
            Button("action.ok", role: .cancel) {}
        } message: {
            Text(comingSoonMessage)
        }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section {
            HStack {
                Text("consent.settings.status")
                Spacer()
                statusBadge
            }
        }
    }

    private var categoriesSection: some View {
        Section {
            // Display the categories (OneTrust-style).
            ForEach(ConsentCategory.allCategories) { category in
                HStack {
                    Image(systemName: category.iconName)
                        .foregroundStyle(category.isRequired ? .orange : .blue)
                        .frame(width: 28)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(LocalizedStringKey(category.nameKey))
                                .font(.subheadline)
                                .fontWeight(.medium)

                            if category.isRequired {
                                Text("consent.category.always.active")
                                    .font(.caption2)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .cornerRadius(4)
                            }
                        }

                        Text(LocalizedStringKey(category.descriptionKey))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Status indicator.
                    let isActive = category.permissions.allSatisfy { manager.hasConsent(for: $0) }
                    Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isActive ? .green : .secondary)
                        .accessibilityHidden(true)
                }
            }

            // Button to modify categories.
            Button {
                showConsentBanner = true
            } label: {
                Label("consent.settings.modify", systemImage: "slider.horizontal.3")
            }
        } header: {
            Text("consent.category.title")
        } footer: {
            Text("consent.category.footer")
        }
    }

    private var actionsSection: some View {
        Section {
            // Export data.
            Button {
                comingSoonMessage = NSLocalizedString("consent.settings.comingsoon.export", comment: "")
                showComingSoonAlert = true
            } label: {
                Label("consent.settings.export", systemImage: "arrow.down.doc")
            }

            // Delete account.
            Button(role: .destructive) {
                comingSoonMessage = NSLocalizedString("consent.settings.comingsoon.delete", comment: "")
                showComingSoonAlert = true
            } label: {
                Label("consent.settings.delete", systemImage: "trash")
            }
        } header: {
            Text("consent.settings.actions")
        } footer: {
            Text("consent.settings.actions.footer.simple")
        }
    }

    // MARK: - Computed

    private var statusBadge: some View {
        Group {
            let consents = manager.getAllConsents()
            let grantedCount = consents.values.filter { $0 == .granted }.count
            let totalCount = consents.count

            if grantedCount == totalCount && totalCount > 0 {
                Label("consent.settings.granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if grantedCount > 0 {
                Label("consent.settings.notGranted", systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
            } else {
                Label("consent.settings.notGranted", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .font(.subheadline)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ConsentSettingsView(manager: BasicConsentManager.shared)
    }
}
