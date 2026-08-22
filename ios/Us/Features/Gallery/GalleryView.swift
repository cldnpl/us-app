import SwiftUI

/// Every photo in the diary, newest first and grouped by month — the same
/// months, in the same order, as the journal pages this screen opens from.
///
/// The photos come from the journal entries themselves, not from the media
/// library: a diary photo belongs to the *day it was written under*, which is
/// the order this screen has to show, and the library deliberately excludes
/// journal photos so they aren't listed twice.
struct GalleryView: View {
    @EnvironmentObject var session: Session

    @State private var entries: [JournalEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var pager: PhotoPagerContext?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 10)]

    private var months: [JournalPhotoMonth] { JournalPhotoMonth.group(entries) }

    var body: some View {
        ZStack {
            Theme.softBackground.ignoresSafeArea()

            if isLoading && entries.isEmpty {
                ProgressView()
            } else if months.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(months) { month in
                            monthSection(month)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Photos")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .fullScreenCover(item: $pager) { ctx in
            JournalPhotoPager(photos: ctx.photos, startIndex: ctx.startIndex) { await load() }
        }
        .overlay(alignment: .bottom) { errorToast }
    }

    private func monthSection(_ month: JournalPhotoMonth) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(month.label)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Theme.ink)
                Text("\(month.photos.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(month.photos.enumerated()), id: \.element.id) { idx, item in
                    RemoteImage(path: item.thumbUrl)
                        .aspectRatio(1, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.white, lineWidth: 3)
                        )
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onTapGesture {
                            // The pager walks the month you tapped into.
                            pager = PhotoPagerContext(photos: month.photos, startIndex: idx)
                        }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 52)).foregroundStyle(Theme.coral)
            Text("No photos yet").font(.title3.bold()).foregroundStyle(Theme.ink)
            Text("Photos you add to a diary entry show up here, month by month.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    @ViewBuilder
    private var errorToast: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.footnote).foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.red.opacity(0.9), in: Capsule())
                .padding(.bottom, 12)
        }
    }

    private func load() async {
        do {
            entries = try await APIClient.shared.listJournal()
            errorMessage = nil
        } catch {
            // A superseded refresh cancels the request; that isn't a failure.
            if !(error is CancellationError || (error as? URLError)?.code == .cancelled) {
                errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
            }
        }
        isLoading = false
    }
}

/// One month of diary photos, in the journal's own order.
struct JournalPhotoMonth: Identifiable {
    let id: String        // yyyy-MM
    let label: String
    let photos: [MediaItem]

    /// Flattens the entries' photos into months, newest first. Entries arrive
    /// date DESC from the server, so preserving that order here keeps this
    /// screen and the diary pages telling the story the same way round.
    @MainActor
    static func group(_ entries: [JournalEntry]) -> [JournalPhotoMonth] {
        let cal = JournalDates.utc
        var order: [String] = []
        var buckets: [String: [MediaItem]] = [:]
        var labels: [String: String] = [:]

        for entry in entries where !entry.photos.isEmpty {
            let comps = cal.dateComponents([.year, .month], from: entry.date)
            let key = String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
            if buckets[key] == nil {
                order.append(key)
                labels[key] = JournalDates.monthYear.string(from: entry.date)
            }
            buckets[key, default: []].append(contentsOf: entry.photos)
        }
        return order.map {
            JournalPhotoMonth(id: $0, label: labels[$0] ?? $0, photos: buckets[$0] ?? [])
        }
    }
}
