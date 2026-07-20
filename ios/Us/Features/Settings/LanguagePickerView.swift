import SwiftUI

/// Pick the language Us. is displayed in.
///
/// Each row shows the language's own name first, because someone scanning for
/// their language recognises "Русский" faster than "Russian". Search matches
/// either name, so both "deutsch" and "german" find German.
struct LanguagePickerView: View {
    @ObservedObject private var languages = LanguageManager.shared
    @State private var query = ""

    var body: some View {
        List(filtered) { language in
            Button {
                languages.select(language)
                Haptics.success()
            } label: {
                row(for: language)
            }
            .tint(.primary)
        }
        .searchable(text: $query, prompt: Text("Search languages"))
        .navigationTitle(Text("Language"))
        .navigationBarTitleDisplayMode(.inline)
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
