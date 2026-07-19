import SwiftUI

/// Full list of quiz topic packs, opened from the "Quiz" card on the Games tab.
struct QuizCategoriesView: View {
    @State private var categories: [QuizCategorySummary] = []
    @State private var errorMessage: String?

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
                        Text("Answer on your own, then compare your answers.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 2)

                        ForEach(categories) { category in
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
                    .padding(20)
                }
            }
        }
        .navigationTitle("Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
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
