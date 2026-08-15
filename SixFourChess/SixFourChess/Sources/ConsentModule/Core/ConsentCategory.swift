import Foundation

/// Consent category, OneTrust-style.
struct ConsentCategory: Identifiable, Equatable, Hashable {
    let id: String
    let nameKey: String
    let descriptionKey: String
    let iconName: String
    let isRequired: Bool
    let permissions: [ConsentPermission]

    /// Strictly necessary cookies, always enabled.
    static let strictlyNecessary = ConsentCategory(
        id: "strictly_necessary",
        nameKey: "consent.category.necessary.name",
        descriptionKey: "consent.category.necessary.desc",
        iconName: "shield.checkered",
        isRequired: true,
        permissions: [.gameDataStorage, .cloudAI]
    )

    /// Performance and analytics, optional.
    static let performance = ConsentCategory(
        id: "performance",
        nameKey: "consent.category.performance.name",
        descriptionKey: "consent.category.performance.desc",
        iconName: "chart.bar.fill",
        isRequired: false,
        permissions: [.performanceAnalytics]
    )

    /// All categories.
    static let allCategories: [ConsentCategory] = [
        .strictlyNecessary,
        .performance
    ]
}
