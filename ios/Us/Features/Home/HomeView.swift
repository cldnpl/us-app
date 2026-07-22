import SwiftUI
import CoreLocation
import Combine

// Demo positions (SharedConfig.demoMode) so the map is visible before real
// location sharing is set up: Claudia in Naples, Alex in Tashkent.
private let sampleMineCoord = CLLocationCoordinate2D(latitude: 40.8518, longitude: 14.2681)
private let samplePartnerCoord = CLLocationCoordinate2D(latitude: 41.2995, longitude: 69.2401)

struct HomeView: View {
    @EnvironmentObject var session: Session
    @StateObject private var location = LocationManager.shared
    @StateObject private var cycle = CycleManager.shared

    @State private var missYouSent = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showProfile = false
    @State private var showAddWidget = false
    @State private var partnerLoc: PartnerLocation?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.softBackground.ignoresSafeArea()
                content
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { BrandLogo() }
                ToolbarItem(placement: .principal) { addWidgetPill }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        Image(systemName: "person.crop.circle").font(.system(size: 24))
                    }
                    .accessibilityLabel("Profile")
                }
            }
            .sheet(isPresented: $showProfile) { ProfileView() }
            .sheet(isPresented: $showAddWidget) { AddWidgetGuideView() }
            .task { await loadPartnerLocation() }
            .task { await cycle.refreshOnAppear() }
            .refreshable { await loadPartnerLocation() }
            .onReceive(location.$currentLocation) { _ in publishDistance() }
        }
    }

    // MARK: - Layout: hero → map → cycle

    private var content: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroButton.padding(.top, 28)
                mapSection
                cycleCards
                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Hero "miss you" button

    private var heroButton: some View {
        Button {
            Task { await sendMissYou() }
        } label: {
            VStack(spacing: 14) {
                Image(systemName: missYouSent ? "heart.fill" : "heart")
                    .font(.system(size: 40, weight: .semibold))
                Text(missYouSent ? "Sent!" : heroTitle)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 180)
            .padding(24)
            .background(Theme.roseGradient, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: Theme.rose.opacity(0.35), radius: 16, y: 8)
            .overlay { if isSending { ProgressView().tint(.white).scaleEffect(1.2) } }
        }
        .buttonStyle(.plain)
        .disabled(isSending || missYouSent)
        .accessibilityLabel(missYouSent ? "Sent" : "Send I miss you to \(partnerName)")
    }

    /// Pill in the nav bar (between the Us. logo and the profile icon).
    private var addWidgetPill: some View {
        Button { showAddWidget = true } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                Text("add widget")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.rose)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.rose.opacity(0.15), in: Capsule())
        }
        .accessibilityLabel("Add widget")
    }

    // MARK: - Cycle cards (partner's shared cycle + your own, when available)

    @ViewBuilder
    private var cycleCards: some View {
        if cycle.userHasCycle == true, cycle.isPregnant, let pg = cycle.pregnancyInsights {
            // She's tracking a pregnancy → show that instead of the cycle.
            NavigationLink { CycleDetailView() } label: {
                PregnancyHomeCard(insights: pg, title: "Your pregnancy")
            }
            .buttonStyle(.plain)
        } else if cycle.userHasCycle == false,
                  let pgp = cycle.partnerPregnancy, pgp.sharing, let due = pgp.dueDate {
            // His partner is expecting and sharing it.
            NavigationLink { CycleDetailView() } label: {
                PregnancyHomeCard(insights: PregnancyEngine.insights(dueDate: due),
                                  title: "\(partnerName) is expecting")
            }
            .buttonStyle(.plain)
        } else {
            switch cycle.userHasCycle {
            case .some(false):
                // He doesn't have a cycle → her current phase + supportive tips.
                NavigationLink { CycleDetailView() } label: {
                    PartnerPeriodCard(partner: cycle.partner, partnerName: partnerName)
                }
                .buttonStyle(.plain)
            case .some(true):
                // She has a cycle → her own tracking (connect Health, then insights).
                if let insights = cycle.insights {
                    NavigationLink { CycleDetailView() } label: { SelfCycleCard(insights: insights) }
                        .buttonStyle(.plain)
                } else {
                    NavigationLink { CycleDetailView() } label: { CycleSetupCard() }
                        .buttonStyle(.plain)
                }
            case nil:
                // Not answered yet (existing users) → neutral entry to the question.
                NavigationLink { CycleDetailView() } label: { CycleSetupCard() }
                    .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Map section (tap to expand)

    @ViewBuilder
    private var mapSection: some View {
        if let mine = mapMine, let partner = mapPartner {
            NavigationLink {
                PartnerMapView()
            } label: {
                DistanceMapCard(mine: mine, partner: partner,
                                myName: myName, partnerName: partnerName, km: mapKm ?? 0)
            }
            .buttonStyle(.plain)
        } else {
            shareLocationCard
        }
    }

    private var shareLocationCard: some View {
        NavigationLink {
            PartnerMapView()
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "map.fill").font(.title).foregroundStyle(Theme.rose)
                Text("See each other on the map")
                    .font(.headline).foregroundStyle(.primary)
                Text("Turn on location so you and \(partnerName) appear here.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Coordinates

    private var myName: String {
        session.user?.displayName ?? (SharedConfig.demoMode ? "Claudia" : "You")
    }
    private var partnerName: String {
        let real = session.partner?.displayName
        // Demo fallback so the sample map/copy reads "Alex".
        if SharedConfig.demoMode, real == nil || real?.isEmpty == true || real == "Partner" {
            return "Alex"
        }
        return real ?? "your partner"
    }

    /// Real location (only while I'm sharing), used for the widget.
    private var realMine: CLLocationCoordinate2D? {
        location.isSharing ? location.currentLocation?.coordinate : nil
    }
    private var realPartner: CLLocationCoordinate2D? {
        guard let p = partnerLoc, p.sharing, let lat = p.lat, let lng = p.lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    private var realKm: Double? { km(realMine, realPartner) }

    /// What the Home map shows — real when available, otherwise the demo
    /// positions (SharedConfig.demoMode) so the map is always populated.
    private var mapMine: CLLocationCoordinate2D? {
        if let real = realMine { return real }
        return SharedConfig.demoMode ? sampleMineCoord : nil
    }
    private var mapPartner: CLLocationCoordinate2D? {
        if let real = realPartner { return real }
        return SharedConfig.demoMode ? samplePartnerCoord : nil
    }
    private var mapKm: Double? { km(mapMine, mapPartner) }

    private func km(_ a: CLLocationCoordinate2D?, _ b: CLLocationCoordinate2D?) -> Double? {
        guard let a, let b else { return nil }
        let la = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let lb = CLLocation(latitude: b.latitude, longitude: b.longitude)
        return la.distance(from: lb) / 1000.0
    }

    // MARK: - Copy

    private var heroTitle: String {
        "Let \(partnerName) know you're thinking of \(session.partnerPronounObject)"
    }

    // MARK: - Actions

    private func loadPartnerLocation() async {
        partnerLoc = try? await APIClient.shared.partnerLocation()
        publishDistance()
    }

    /// Keep the distance widget in sync with what the Home map shows (real when
    /// available; the DEBUG sample otherwise, so the test widget matches).
    private func publishDistance() {
        session.publishDistance(mapKm)
    }

    private func sendMissYou() async {
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            _ = try await APIClient.shared.sendMissYou()
            Haptics.tap(.heavy)
            withAnimation { missYouSent = true }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { missYouSent = false }
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }
}
