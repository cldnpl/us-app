import SwiftUI

/// Pick the language Leyla is displayed in.
///
/// Each row shows the language's own name first, because someone scanning for
/// their language recognises "Русский" faster than "Russian". Search matches
/// either name, so both "deutsch" and "german" find German.
struct LanguagePickerView: View {
    @ObservedObject private var languages = LanguageManager.shared
    @ObservedObject private var translations = TranslationStore.shared
    @State private var query = ""

    var body: some View {
        List(filtered) { language in
            Button {
                Task {
                    await languages.select(language)
                    Haptics.success()
                }
            } label: {
                row(for: language)
            }
            .tint(.primary)
            .disabled(translations.isLoading)
        }
        .searchable(text: $query, prompt: Text(loc: "Search languages"))
        .navigationTitle(Text(loc: "Language"))
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            // Blocking, not inline: every string on screen is about to change
            // at once, so a partial re-render mid-fetch would look broken
            // rather than just slow.
            if translations.isLoading {
                ZStack {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                        .padding(20)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .transition(.opacity)
            }
        }
        .animation(.default, value: translations.isLoading)
    }

    private func row(for language: AppLanguage) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: language.endonym)
                // Skip the redundant subtitle when both names are identical
                // (English, Filipino, Deutsch-in-English, …).
                if language.englishName != language.endonym {
                    Text(verbatim: language.englishName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if language == languages.current {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.rose)
            }
        }
        // The list itself is always left-to-right even when the app is mirrored:
        // it's a list of languages, not localised content.
        .environment(\.layoutDirection, .leftToRight)
    }

    private var filtered: [AppLanguage] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return AppLanguage.all }
        return AppLanguage.all.filter {
            $0.endonym.localizedCaseInsensitiveContains(trimmed)
                || $0.englishName.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
