import SwiftUI

struct JournalView: View {
    @EnvironmentObject var session: Session

    @State private var milestones: [Milestone] = []
    @State private var reunions: [Reunion] = []
    @State private var showAdd = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let days = session.daysTogether {
                    Section {
                        HStack(spacing: 14) {
                            Image(systemName: "heart.fill")
                                .font(.title2).foregroundStyle(Theme.coral)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(days) days together").font(.headline)
                                if let start = session.couple?.startDate {
                                    Text("since \(start.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    NavigationLink { GalleryView() } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Photos").font(.headline)
                                Text("Your shared gallery")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "photo.on.rectangle.angled")
                                .foregroundStyle(Theme.coral)
                        }
                    }
                }

                if !reunions.isEmpty {
                    Section("Countdowns") {
                        ForEach(reunions) { reunion in
                            momentRow(title: reunion.title, date: reunion.targetDate,
                                      symbol: "airplane", countdown: true)
                        }
                        .onDelete { indexes in Task { await deleteReunions(indexes) } }
                    }
                }

                Section("Milestones") {
                    if milestones.isEmpty {
                        Text("Add your first date, first kiss, anniversary…")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(milestones) { milestone in
                        momentRow(title: milestone.title, date: milestone.date,
                                  symbol: "star.fill", countdown: false)
                    }
                    .onDelete { indexes in Task { await deleteMilestones(indexes) } }
                }
            }
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus.circle.fill") }
                }
            }
            .task { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showAdd) {
                AddMomentSheet { await load() }
            }
            .overlay(alignment: .bottom) {
                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.red.opacity(0.9), in: Capsule()).padding(.bottom, 12)
                }
            }
        }
    }

    private func momentRow(title: String, date: Date, symbol: String, countdown: Bool) -> some View {
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: date)
        let days = Calendar.current.dateComponents([.day], from: today, to: target).day ?? 0
        return HStack {
            Image(systemName: symbol).foregroundStyle(Theme.coral)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if countdown {
                VStack(spacing: 0) {
                    Text("\(abs(days))").font(.title3.bold()).foregroundStyle(Theme.coral)
                    Text(days >= 0 ? "days" : "ago").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func load() async {
        do {
            async let m = APIClient.shared.listMilestones()
            async let r = APIClient.shared.listReunions()
            milestones = try await m
            reunions = try await r
            errorMessage = nil
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }

    private func deleteReunions(_ indexes: IndexSet) async {
        for i in indexes { try? await APIClient.shared.deleteReunion(id: reunions[i].id) }
        await load()
    }

    private func deleteMilestones(_ indexes: IndexSet) async {
        for i in indexes { try? await APIClient.shared.deleteMilestone(id: milestones[i].id) }
        await load()
    }
}

struct AddMomentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onDone: () async -> Void

    @State private var isReunion = false
    @State private var title = ""
    @State private var date = Date()
    @State private var saving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $isReunion) {
                    Text("Milestone").tag(false)
                    Text("Countdown").tag(true)
                }
                .pickerStyle(.segmented)

                TextField(isReunion ? "e.g. Next visit ✈️" : "e.g. First date", text: $title)
                DatePicker("Date", selection: $date, displayedComponents: .date)

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle(isReunion ? "Add countdown" : "Add milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || saving)
                }
            }
        }
    }

    private func save() async {
        saving = true
        errorMessage = nil
        let iso = date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        do {
            if isReunion {
                _ = try await APIClient.shared.createReunion(title: title, targetDate: iso)
            } else {
                _ = try await APIClient.shared.createMilestone(title: title, date: iso, kind: "milestone")
            }
            await onDone()
            dismiss()
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
            saving = false
        }
    }
}
