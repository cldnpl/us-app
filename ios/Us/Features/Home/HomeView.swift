import SwiftUI
import CoreLocation
import Combine

struct HomeView: View {
    @EnvironmentObject var session: Session
    @StateObject private var location = LocationManager.shared

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
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 24))
                    }
                    .accessibilityLabel("Profile")
                }
            }
            .sheet(isPresented: $showProfile) { ProfileView() }
            .sheet(isPresented: $showAddWidget) { AddWidgetGuideView() }
            .task { await loadPartnerLocation() }
            .refreshable { await loadPartnerLocation() }
            .onReceive(location.$currentLocation) { _ in publishDistance() }
        }
    }

    // MARK: - Layout (adapts when the distance map is visible)

    @ViewBuilder
    private var content: some View {
        if let km = distanceKm, let mine = myCoord, let partner = partnerCoord {
            ScrollView {
                VStack(spacing: 18) {
                    heroButton(compact: true).padding(.top, 10)
                    addWidgetLink
                    NavigationLink {
                        PartnerMapView()
                    } label: {
                        DistanceMapCard(mine: mine, partner: partner,
                                        myName: myName, partnerName: partnerName, km: km)
                    }
                    .buttonStyle(.plain)
                    if let errorMessage { errorText(errorMessage) }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        } else {
            VStack(spacing: 22) {
                Spacer(minLength: 12)
                heroButton(compact: false)
                addWidgetLink
                if let errorMessage { errorText(errorMessage) }
                Spacer(minLength: 0)
                whereLink
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Hero "miss you" button

    private func heroButton(compact: Bool) -> some View {
        Button {
            Task { await sendMissYou() }
        } label: {
            VStack(spacing: compact ? 10 : 18) {
                Image(systemName: missYouSent ? "heart.fill" : "heart")
                    .font(.system(size: compact ? 32 : 46, weight: .semibold))
                Text(missYouSent ? "Sent 💜" : heroTitle)
                    .font(.system(compact ? .headline : .title2, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(compact ? 2 : 4)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: compact ? 130 : 240)
            .padding(compact ? 18 : 28)
            .background(Theme.roseGradient, in: RoundedRectangle(cornerRadius: compact ? 28 : 36, style: .continuous))
            .shadow(color: Theme.rose.opacity(0.35), radius: compact ? 14 : 20, y: 10)
            .overlay { if isSending { ProgressView().tint(.white).scaleEffect(1.2) } }
        }
        .buttonStyle(.plain)
        .disabled(isSending || missYouSent)
        .accessibilityLabel(missYouSent ? "Sent" : "Send I miss you to \(partnerName)")
    }

    private var addWidgetLink: some View {
        Button { showAddWidget = true } label: {
            Text("add widget")
                .font(.headline).underline()
                .foregroundStyle(Theme.rose)
        }
    }

    /// Fallback link (shown only when the distance map isn't available).
    private var whereLink: some View {
        NavigationLink {
            PartnerMapView()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "location.fill.viewfinder")
                Text("Where's \(partnerName)?")
                Image(systemName: "chevron.right").font(.caption2)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.rose)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
        }
    }

    private func errorText(_ message: String) -> some View {
        Text(message).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
    }

    // MARK: - Distance

    private var myName: String { session.user?.displayName ?? "You" }
    private var partnerName: String { session.partner?.displayName ?? "your partner" }

    private var myCoord: CLLocationCoordinate2D? {
        guard location.isSharing else { return nil }
        return location.currentLocation?.coordinate
    }

    private var partnerCoord: CLLocationCoordinate2D? {
        guard let p = partnerLoc, p.sharing, let lat = p.lat, let lng = p.lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    /// Distance in km, only when BOTH partners are sharing.
    private var distanceKm: Double? {
        guard let mine = myCoord, let pc = partnerCoord else { return nil }
        let a = CLLocation(latitude: mine.latitude, longitude: mine.longitude)
        let b = CLLocation(latitude: pc.latitude, longitude: pc.longitude)
        return a.distance(from: b) / 1000.0
    }

    // MARK: - Copy

    /// "Let Alex know you're thinking of her" — name + onboarding pronoun.
    private var heroTitle: String {
        "Let \(partnerName) know you're thinking of \(session.partnerPronounObject)"
    }

    // MARK: - Actions

    private func loadPartnerLocation() async {
        partnerLoc = try? await APIClient.shared.partnerLocation()
        publishDistance()
    }

    /// Keep the distance widget in sync with what Home is showing.
    private func publishDistance() {
        session.publishDistance(distanceKm)
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
