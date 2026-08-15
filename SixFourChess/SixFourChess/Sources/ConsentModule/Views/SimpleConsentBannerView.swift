import SwiftUI

/// Simplified consent banner for privacy preferences.
struct SimpleConsentBannerView: View {
    let manager: ConsentManagerProtocol
    let onConsentGiven: () -> Void
    let onConsentDenied: () -> Void
    let showCloseButton: Bool // Shows the close button (false at app launch).

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedCategories: Set<String> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                        // Scrollable content.
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header.
                        headerSection

                        // Categories.
                        categoriesSection

                        // Footer.
                        footerSection
                    }
                    .padding()
                }

                // Fixed action buttons at the bottom.
                actionButtons
                    .padding()
                    .background(backgroundColor)
            }
            .background(backgroundColor)
            .navigationTitle("consent.settings.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showCloseButton {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            onConsentDenied()
                            dismiss()
                        } label: {
                            ZStack {
                                // Liquid glass background.
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 32, height: 32)

                                // X icon.
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(secondaryTextColor)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("a11y.close".localized)
                    }
                }
            }
        }
        .onAppear {
            // Load the current state from the manager to reflect previous choices.
            var initialSelection: Set<String> = []
            
            for category in ConsentCategory.allCategories {
                // A category is active if it is required or if the user has already consented.
                let isGranted = category.permissions.allSatisfy { manager.hasConsent(for: $0) }
                if category.isRequired || isGranted {
                    initialSelection.insert(category.id)
                }
            }
            
            selectedCategories = initialSelection
        }
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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .font(.title2)
                    .foregroundStyle(accentColor)
                    .accessibilityHidden(true)

                Text("consent.banner.headline.simple")
                    .font(.system(.title2, design: .serif)).fontWeight(.semibold)
                    .foregroundStyle(primaryTextColor)
            }

            Text("consent.banner.message.simple")
                .font(.subheadline)
                .foregroundStyle(secondaryTextColor)
        }
    }

    private var categoriesSection: some View {
        VStack(spacing: 12) {
            ForEach(ConsentCategory.allCategories) { category in
                CategoryCard(
                    category: category,
                    isSelected: selectedCategories.contains(category.id),
                    onToggle: { isOn in
                        if isOn {
                            selectedCategories.insert(category.id)
                        } else if !category.isRequired {
                            selectedCategories.remove(category.id)
                        }
                    }
                )
            }
        }
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .background(secondaryTextColor.opacity(0.3))

            // Link to the policy.
            NavigationLink {
                ConsentModule.makePrivacyPolicyView()
            } label: {
                HStack {
                    Image(systemName: "doc.text")
                        .accessibilityHidden(true)
                    Text("privacy.title")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .accessibilityHidden(true)
                }
                .font(.subheadline)
                .foregroundStyle(accentColor)
            }

            Text("consent.banner.footer.info")
                .font(.caption)
                .foregroundStyle(secondaryTextColor)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Save my choices button (appears after a custom or default selection).
            Button {
                saveSelection()
            } label: {
                Text("consent.banner.save") // Keep this localization key in sync.
                    .font(.system(.body, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(accentColor)
                    .foregroundStyle(backgroundColor)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("a11y.consent.save".localized)
            
            // Secondary button: accept all.
            Button {
                acceptAll()
            } label: {
                Text("consent.banner.accept_all") // "Accept all".
                    .font(.system(.body, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(cardBackgroundColor)
                    .foregroundStyle(primaryTextColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(secondaryTextColor.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("a11y.consent.acceptAll".localized)

            // Link: refuse non-essential items (equivalent to refusing everything except necessary items).
            Button {
                refuseAll()
            } label: {
                Text("consent.banner.refuse_non_essential")
                    .font(.subheadline)
                    .underline()
                    .foregroundStyle(secondaryTextColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("a11y.consent.refuse".localized)
            .padding(.top, 4)
        }
    }

    // MARK: - Actions
    
    private func saveSelection() {
        // 1. Identify granted permissions.
        let grantedCategories = ConsentCategory.allCategories.filter { selectedCategories.contains($0.id) }
        let grantedPermissions = Set(grantedCategories.flatMap { $0.permissions })
        
        // 2. Identify refused permissions (explicitly not selected).
        let refusedCategories = ConsentCategory.allCategories.filter { !selectedCategories.contains($0.id) }
        let refusedPermissions = Set(refusedCategories.flatMap { $0.permissions })
        
        // 3. Apply the selection.
        manager.grantConsent(for: grantedPermissions)
        manager.revokeConsent(for: refusedPermissions)
        
        Logger.success("Custom selection saved", subsystem: .consent)
        onConsentGiven()
        dismiss()
    }

    private func acceptAll() {
        // Grant all permissions.
        let allPermissions = Set(ConsentCategory.allCategories.flatMap { $0.permissions })
        manager.grantConsent(for: allPermissions)

        Logger.success("All categories accepted", subsystem: .consent)
        onConsentGiven()
        dismiss()
    }

    private func refuseAll() {
        // Deny all optional permissions.
        let optionalPermissions = Set(
            ConsentCategory.allCategories
                .filter { !$0.isRequired }
                .flatMap { $0.permissions }
        )
        manager.revokeConsent(for: optionalPermissions)

        // Grant only the required permissions.
        let requiredPermissions = Set(
            ConsentCategory.allCategories
                .filter { $0.isRequired }
                .flatMap { $0.permissions }
        )
        manager.grantConsent(for: requiredPermissions)

        Logger.info("Optional categories refused, only required granted", subsystem: .consent)
        onConsentDenied()
        dismiss()
    }

    private func continueWithoutAccepting() {
        // Grant only the strictly necessary permissions.
        let requiredPermissions = Set(
            ConsentCategory.allCategories
                .filter { $0.isRequired }
                .flatMap { $0.permissions }
        )
        manager.grantConsent(for: requiredPermissions)

        Logger.info("Continue without accepting - only required granted", subsystem: .consent)
        onConsentDenied()
        dismiss()
    }
}

// MARK: - Category Card

struct CategoryCard: View {
    let category: ConsentCategory
    let isSelected: Bool
    let onToggle: (Bool) -> Void

    @State private var localIsSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    init(category: ConsentCategory, isSelected: Bool, onToggle: @escaping (Bool) -> Void) {
        self.category = category
        self.isSelected = isSelected
        self.onToggle = onToggle
        _localIsSelected = State(initialValue: isSelected)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: category.iconName)
                .foregroundStyle(category.isRequired ? accentColor : accentColor.opacity(0.7))
                .font(.title3)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(LocalizedStringKey(category.nameKey))
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(primaryTextColor)

                    if category.isRequired {
                        Text("consent.category.always.active")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(backgroundColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(accentColor)
                            .cornerRadius(6)
                    }
                }

                Text(LocalizedStringKey(category.descriptionKey))
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
            }

            Spacer()

            Toggle("", isOn: $localIsSelected)
                .labelsHidden()
                .disabled(category.isRequired)
                .tint(accentColor)
                .onChange(of: localIsSelected) { _, newValue in
                    onToggle(newValue)
                }
        }
        .padding(14)
        .background(cardBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(secondaryTextColor.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(12)
        .onChange(of: isSelected) { _, newValue in
            localIsSelected = newValue
        }
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
}

// MARK: - Preview

#Preview {
    SimpleConsentBannerView(
        manager: BasicConsentManager.shared,
        onConsentGiven: { print("Consent given") },
        onConsentDenied: { print("Consent denied") },
        showCloseButton: true
    )
}
