import SwiftUI

/// One calendar day of the diary — both partners' entries for that date.
struct JournalDay: Identifiable {
    let id: String        // yyyy-MM-dd key
    let date: Date
    let entries: [JournalEntry]

    var monthLabel: String { JournalDates.monthYear.string(from: date) }

    /// Groups server-ordered entries (already date DESC) into days, preserving
    /// that newest-first order.
    static func group(_ entries: [JournalEntry]) -> [JournalDay] {
        let cal = JournalDates.utc
        var order: [String] = []
        var buckets: [String: [JournalEntry]] = [:]
        for e in entries {
            let comps = cal.dateComponents([.year, .month, .day], from: e.date)
            let key = String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(e)
        }
        return order.map { key in
            let items = buckets[key]!
            return JournalDay(id: key, date: items[0].date, entries: items)
        }
    }
}

/// A single day card: a coral date badge on the left, then each partner's block
/// (name + text + optional photo stack), divided like a scrapbook page.
struct JournalDayCard: View {
    let day: JournalDay
    let authorName: (String) -> String
    let isMine: (String) -> Bool
    let onOpenPhotos: ([MediaItem], Int) -> Void
    let onEdit: (JournalEntry) -> Void
    let onDelete: (JournalEntry) -> Void

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 16) {
                dateBadge
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(day.entries.enumerated()), id: \.element.id) { idx, entry in
                        if idx > 0 { Divider() }
                        block(entry)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var dateBadge: some View {
        VStack(spacing: 4) {
            Text(JournalDates.dayNumber.string(from: day.date))
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(Theme.roseGradient, in: Circle())
                .shadow(color: Theme.rose.opacity(0.35), radius: 6, y: 3)
            Text(JournalDates.weekdayShort.string(from: day.date))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
    }

    @ViewBuilder
    private func block(_ entry: JournalEntry) -> some View {
        let body = VStack(alignment: .leading, spacing: 8) {
            Text("\(authorName(entry.authorId)):")
                .font(.subheadline.bold())
                .foregroundStyle(isMine(entry.authorId) ? Theme.coral : Theme.ink)

            if !entry.body.isEmpty {
                Text(entry.body)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !entry.photos.isEmpty {
                PhotoStackView(photos: entry.photos) { start in
                    onOpenPhotos(entry.photos, start)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())

        // Only your own entry can be edited or removed — swipe it left for the
        // actions (long-press still works too). The partner's block is static.
        if isMine(entry.authorId) {
            SwipeToDelete(onDelete: { onDelete(entry) }, onEdit: { onEdit(entry) }) {
                body
            }
            .contextMenu {
                Button { onEdit(entry) } label: { Label("Edit", systemImage: "pencil") }
                Button(role: .destructive) { onDelete(entry) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            body
        }
    }
}

/// A playful "photos tossed on the page" preview: up to three overlapping
/// thumbnails with a stable tilt; a +N badge when there are more. Tapping opens
/// the fullscreen pager at that photo.
struct PhotoStackView: View {
    let photos: [MediaItem]
    let onTap: (Int) -> Void

    private let size: CGFloat = 104
    private var shown: [MediaItem] { Array(photos.prefix(3)) }

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                ForEach(Array(shown.enumerated().reversed()), id: \.element.id) { idx, item in
                    RemoteImage(path: item.thumbUrl)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.white, lineWidth: 4)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
                        .rotationEffect(.degrees(tilt(idx)))
                        .offset(x: CGFloat(idx) * 22, y: CGFloat(idx) * 6)
                        .zIndex(Double(shown.count - idx))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if photos.count > shown.count {
                    Text("+\(photos.count - shown.count)")
                        .font(.caption.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Theme.coral, in: Capsule())
                        .offset(x: 30, y: 4)
                }
            }
            .padding(.trailing, CGFloat(max(shown.count - 1, 0)) * 22 + 8)
            .padding(.vertical, 4)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap(0) }
        .accessibilityLabel("\(photos.count) photos")
    }

    // Stable tilt per stack position, so it doesn't jump between renders.
    private func tilt(_ idx: Int) -> Double { [-6.0, 4.0, -3.0][idx % 3] }
}
