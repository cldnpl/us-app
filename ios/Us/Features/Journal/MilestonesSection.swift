import SwiftUI

/// The editable Milestones card at the top of the Journal. Rows can be tapped to
/// edit inline (title + date), removed via context menu, and a trailing
/// "Add milestone" reveals an inline editor — with tappable suggestions — right
/// below the existing ones.
struct MilestonesSection: View {
    let milestones: [Milestone]
    let onAdd: (String, Date) async -> Void
    let onUpdate: (String, String, Date) async -> Void
    let onDelete: (String) async -> Void

    /// nil = not editing, "" = adding a new one, otherwise the id being edited.
    @State private var editingID: String?
    @State private var draftTitle = ""
    @State private var draftDate = Date()
    @State private var saving = false

    static let suggestions = [
        "First date", "First kiss", "First \u{201C}I love you\u{201D}", "First trip",
        "Anniversary", "Moved in together", "Met the family", "Got engaged",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Milestones").font(.title2.weight(.heavy)).foregroundStyle(Theme.ink)
                Image(systemName: "heart.fill").font(.headline).foregroundStyle(Theme.rose)
                Spacer()
            }

            Card {
                VStack(alignment: .leading, spacing: 0) {
                    if milestones.isEmpty && editingID != "" {
                        Text("Add your firsts — first date, first kiss, the day you met…")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                    }

                    ForEach(Array(milestones.enumerated()), id: \.element.id) { idx, m in
                        if editingID == m.id {
                            editor(saveTitle: "Save") {
                                await onUpdate(m.id, trimmed, draftDate); finishEditing()
                            }
                        } else {
                            row(m)
                            if idx < milestones.count - 1 || editingID == "" { Divider() }
                        }
                    }

                    if editingID == "" {
                        editor(saveTitle: "Add") { await onAdd(trimmed, draftDate); finishEditing() }
                    } else {
                        addButton
                    }
                }
            }
        }
    }

    // MARK: - Rows

    private func row(_ m: Milestone) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(Theme.rose).frame(width: 7, height: 7)
                .padding(.top, 8) // aligns the bullet with the title's center
            VStack(alignment: .leading, spacing: 3) {
                Text(m.title).font(.headline).foregroundStyle(Theme.ink)
                Text(dayString(m.date))
                    .font(.subheadline).foregroundStyle(Theme.coral)
            }
            Spacer()
            Image(systemName: "pencil").font(.footnote).foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { beginEdit(m) }
        .contextMenu {
            Button(role: .destructive) { Task { await onDelete(m.id) } } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var addButton: some View {
        Button { beginAdd() } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill").font(.title3)
                Text("Add milestone").font(.subheadline.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(Theme.coral)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Inline editor

    @ViewBuilder
    private func editor(saveTitle: String, save: @escaping () async -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Milestone (e.g. First date)", text: $draftTitle)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.suggestions, id: \.self) { s in
                        Button { draftTitle = s } label: {
                            Text(s).font(.caption.weight(.semibold))
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Theme.blush.opacity(0.30), in: Capsule())
                                .foregroundStyle(Theme.ink)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            DatePicker("Date", selection: $draftDate, displayedComponents: .date)
                .font(.subheadline)

            HStack {
                Button("Cancel") { finishEditing() }
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    saving = true
                    Task { await save(); saving = false }
                } label: {
                    Text(saving ? "Saving…" : saveTitle).font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.coral)
                .disabled(trimmed.isEmpty || saving)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - State transitions

    private var trimmed: String { draftTitle.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func beginAdd() {
        draftTitle = ""; draftDate = Date()
        withAnimation { editingID = "" }
    }

    private func beginEdit(_ m: Milestone) {
        draftTitle = m.title; draftDate = m.date
        withAnimation { editingID = m.id }
    }

    private func finishEditing() {
        withAnimation { editingID = nil }
        draftTitle = ""
    }
}
