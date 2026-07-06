import SwiftUI

/// The Journal tab: editable **Milestones** at the top, then a reverse-chrono
/// **diary** — one card per day grouping both partners' text and photos, newest
/// first. Everything is shared: what one partner writes, the other sees.
struct JournalView: View {
    @EnvironmentObject var session: Session

    @State private var milestones: [Milestone] = []
    @State private var entries: [JournalEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var showAddEntry = false
    @State private var editingEntry: JournalEntry?
    @State private var pager: PhotoPagerContext?
    @State private var showGallery = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    MilestonesSection(
                        milestones: milestones,
                        onAdd: { title, date in await addMilestone(title, date) },
                        onUpdate: { id, title, date in await updateMilestone(id, title, date) },
                        onDelete: { id in await deleteMilestone(id) }
                    )

                    journalFeed
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Theme.softBackground.ignoresSafeArea())
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showGallery = true } label: {
                        Image(systemName: "photo.stack")
                    }
                    .accessibilityLabel("Photos")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddEntry = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Write in journal")
                }
            }
            .task { await load() }
            .refreshable { await load() }
            .navigationDestination(isPresented: $showGallery) { GalleryView() }
            .sheet(isPresented: $showAddEntry) {
                AddJournalEntrySheet(existing: nil) { await load() }
            }
            .sheet(item: $editingEntry) { entry in
                AddJournalEntrySheet(existing: entry) { await load() }
            }
            .fullScreenCover(item: $pager) { ctx in
                JournalPhotoPager(photos: ctx.photos, startIndex: ctx.startIndex) { await load() }
            }
            .overlay(alignment: .bottom) { errorToast }
        }
    }

    // MARK: - Journal feed

    @ViewBuilder
    private var journalFeed: some View {
        let days = JournalDay.group(entries)
        VStack(alignment: .leading, spacing: 18) {
            if isLoading && entries.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 24)
            } else if days.isEmpty {
                emptyState
            } else {
                ForEach(Array(days.enumerated()), id: \.element.id) { idx, day in
                    if idx == 0 || days[idx - 1].monthLabel != day.monthLabel {
                        Text(day.monthLabel)
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(Theme.ink)
                            .padding(.top, idx == 0 ? 0 : 6)
                    }
                    JournalDayCard(
                        day: day,
                        authorName: authorName,
                        isMine: isMine,
                        onOpenPhotos: { photos, start in pager = PhotoPagerContext(photos: photos, startIndex: start) },
                        onEdit: { editingEntry = $0 },
                        onDelete: { entry in Task { await deleteEntry(entry) } }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 46)).foregroundStyle(Theme.coral)
            Text("Your story starts here")
                .font(.title3.bold()).foregroundStyle(Theme.ink)
            Text("Tap ✎ to write about today — add a few words, some photos, or both.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var errorToast: some View {
        if let errorMessage {
            Text(errorMessage).font(.footnote).foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.red.opacity(0.9), in: Capsule())
                .padding(.bottom, 12)
        }
    }

    // MARK: - Author identity

    private func authorName(_ id: String) -> String {
        if id == session.user?.id { return session.user?.displayName ?? "You" }
        return session.partner?.displayName ?? "Partner"
    }

    private func isMine(_ id: String) -> Bool { id == session.user?.id }

    // MARK: - Data

    private func load() async {
        // Fetch independently so a failure in one section never blanks the other.
        do {
            milestones = try await APIClient.shared.listMilestones()
            errorMessage = nil
        } catch { report(error) }
        do {
            entries = try await APIClient.shared.listJournal()
            errorMessage = nil
        } catch { report(error) }
        isLoading = false
    }

    /// Surfaces an error, but ignores task-cancellation noise (URLError.cancelled
    /// / CancellationError) that fires when a refresh is superseded.
    private func report(_ error: Error) {
        if error is CancellationError { return }
        if let urlErr = error as? URLError, urlErr.code == .cancelled { return }
        errorMessage = message(for: error)
    }

    private func addMilestone(_ title: String, _ date: Date) async {
        do {
            _ = try await APIClient.shared.createMilestone(title: title, date: isoDay(date), kind: "milestone")
            Haptics.success()
            await load()
        } catch { errorMessage = message(for: error) }
    }

    private func updateMilestone(_ id: String, _ title: String, _ date: Date) async {
        do {
            _ = try await APIClient.shared.updateMilestone(id: id, title: title, date: isoDay(date))
            await load()
        } catch { errorMessage = message(for: error) }
    }

    private func deleteMilestone(_ id: String) async {
        do {
            try await APIClient.shared.deleteMilestone(id: id)
            await load()
        } catch { errorMessage = message(for: error) }
    }

    private func deleteEntry(_ entry: JournalEntry) async {
        do {
            try await APIClient.shared.deleteJournalEntry(id: entry.id)
            await load()
        } catch { errorMessage = message(for: error) }
    }

    private func message(for error: Error) -> String {
        (error as? APIErrorResponse)?.error ?? error.localizedDescription
    }
}

/// Identifies a set of photos + a starting index for the fullscreen pager.
struct PhotoPagerContext: Identifiable {
    let id = UUID()
    let photos: [MediaItem]
    let startIndex: Int
}

// The API carries calendar dates (milestone.date, journal entry_date) as
// midnight UTC. We therefore build and read them in UTC so a user in a timezone
// behind GMT doesn't see the day shift by one.
enum JournalDates {
    static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    static let medium = formatter("MMM d, yyyy")
    static let dayNumber = formatter("d")
    static let weekdayShort = formatter("EEE")
    static let monthYear = formatter("MMMM yyyy")

    private static func formatter(_ template: String) -> DateFormatter {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.setLocalizedDateFormatFromTemplate(template)
        return f
    }
}

/// Formats a Date as `YYYY-MM-DD` (UTC calendar day) for the API.
func isoDay(_ date: Date) -> String {
    let c = JournalDates.utc.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
}

/// A human-readable calendar day (UTC), e.g. "Feb 12, 2026".
func dayString(_ date: Date) -> String { JournalDates.medium.string(from: date) }
