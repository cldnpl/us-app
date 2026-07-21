import SwiftUI

/// Full list of quiz topic packs, opened from the "Quiz" card on the Games tab.
struct QuizCategoriesView: View {
    @EnvironmentObject private var premium: PremiumStore
    @State private var categories: [QuizCategorySummary] = []
    @State private var errorMessage: String?
    @State private var lockedCategory: QuizCategorySummary?

    var body: some View {
        ZStack {
            Theme.softBackground.ignoresSafeArea()
            ScrollView {
                if categories.isEmpty && errorMessage == nil {
                    ProgressView().padding(.top, 60)
                } else if let errorMessage, categories.isEmpty {
                    Text(errorMessage).font(.footnote).foregroundStyle(.secondary).padding(.top, 60)
                } else {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        Text(premium.isPremium
                             ? "Answer on your own, then compare your answers."
                             : "Answer on your own, then compare your answers. Two packs are free — Premium opens the rest.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 2)

                        ForEach(categories) { category in
                            if premium.isQuizCategoryLocked(category.id) {
                                Button {
                                    Haptics.tap()
                                    lockedCategory = category
                                } label: {
                                    CategoryCard(category: category, locked: true)
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink {
                                    QuizCategoryDetailView(categoryId: category.id,
                                                           categoryTitle: category.title,
                                                           categoryIcon: category.icon)
                                } label: {
                                    CategoryCard(category: category)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 40)   // clear the floating tab bar
                }
            }
        }
        .navigationTitle("Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $lockedCategory) { category in
            PaywallView(trigger: .quizCategory(category.title))
        }
    }

    private func load() async {
        do {
            categories = try await APIClient.shared.getQuizCategories()
            errorMessage = nil
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }
}
