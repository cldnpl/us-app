import SwiftUI
import MapKit
import WidgetKit

struct MapPin: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let avatarPath: String?
}

struct PartnerMapView: View {
    @EnvironmentObject var session: Session
    @StateObject private var location = LocationManager.shared

    @State private var partner: PartnerLocation?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30, longitude: 20),
        span: MKCoordinateSpan(latitudeDelta: 90, longitudeDelta: 90)
    )

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(coordinateRegion: $region, annotationItems: annotations) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    VStack(spacing: 2) {
                        // Show the person's profile photo on the map when they've
                        // uploaded one; keep the heart as the warm fallback.
                        Avatar(path: item.avatarPath, name: item.name, size: 36)
                            .background(Circle().fill(.background).padding(-3))
                        Text(verbatim: item.name.loc)
                            .font(.caption2).bold()
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            // See DistanceViews: a fixed white capsule under
                            // `.primary` text is invisible in dark mode.
                            .background(.thickMaterial, in: Capsule())
                    }
                }
            }
            .ignoresSafeArea(edges: .top)

            controlCard
        }
        .navigationTitle(Text(loc: "Map"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadPartner() }
        .task { await pollPartner() }
        .refreshable { await loadPartner() }
        .onAppear { fitRegion() }
        .onReceive(location.$currentLocation) { _ in fitRegion() }
    }

    // MARK: - Coordinates & pins

    private var myName: String {
        session.user?.displayName ?? (SharedConfig.demoMode ? "Claudia" : "You")
    }
    private var partnerName: String {
        let real = partner?.partnerName ?? session.partner?.displayName
        // Demo fallback so the sample map reads "Alex".
        if SharedConfig.demoMode, real == nil || real?.isEmpty == true || real == "Partner" {
            return "Alex"
        }
        return real ?? "Partner"
    }

    private var myCoord: CLLocationCoordinate2D? {
        if location.isSharing, let c = location.currentLocation?.coordinate { return c }
        // Naples (demo)
        return SharedConfig.demoMode ? CLLocationCoordinate2D(latitude: 40.8518, longitude: 14.2681) : nil
    }

    private var partnerCoord: CLLocationCoordinate2D? {
        if let p = partner, p.sharing, let lat = p.lat, let lng = p.lng {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        // Tashkent (demo)
        return SharedConfig.demoMode ? CLLocationCoordinate2D(latitude: 41.2995, longitude: 69.2401) : nil
    }

    private var annotations: [MapPin] {
        var pins: [MapPin] = []
        if let m = myCoord {
            pins.append(MapPin(name: myName, coordinate: m, avatarPath: session.user?.avatarPath))
        }
        if let pc = partnerCoord {
            pins.append(MapPin(name: partnerName, coordinate: pc, avatarPath: session.partner?.avatarPath))
        }
        return pins
    }

    private func fitRegion() {
        let coords = annotations.map(\.coordinate)
        guard !coords.isEmpty else { return }
        guard coords.count > 1 else {
            region = MKCoordinateRegion(center: coords[0],
                                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
            return
        }
        let lats = coords.map(\.latitude), lngs = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2,
                                            longitude: (lngs.min()! + lngs.max()!) / 2)
        let span = MKCoordinateSpan(latitudeDelta: (lats.max()! - lats.min()!) * 1.6 + 0.1,
                                    longitudeDelta: (lngs.max()! - lngs.min()!) * 1.6 + 0.1)
        region = MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Sharing control

    private var controlCard: some View {
        VStack(spacing: 12) {
            if let km = distanceKm {
                Text(verbatim: "%@ km apart".loc(NSNumber(value: Int(km.rounded()))))
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(Theme.rose)
            }
            if let p = partner, p.sharing {
                Label(loc: "\(partnerName) is sharing 💜", systemImage: "location.fill")
                    .font(.subheadline)
            } else {
                Text(loc: "\(partnerName) isn't sharing their location right now.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Toggle(isOn: Binding(
                get: { location.isSharing },
                set: { $0 ? location.startSharing() : location.stopSharing() }
            )) {
                Text(location.isSharing ? "Sharing my location" : "Share my location")
            }
            .tint(Theme.rose)

            if location.authorizationStatus == .denied {
                Text(loc: "Enable location access in Settings to share.")
                    .font(.caption).foregroundStyle(.red)
            } else if location.isSharing && !location.updatesInBackground {
                // Without "Always", our own position only moves while the app is
                // open — which is exactly what makes the widget look frozen.
                Button {
                    location.requestAlwaysIfPossible()
                } label: {
                    Label(loc: "Keep the distance updating when Us is closed", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
                .tint(Theme.rose)
            }
            Text(loc: "Off unless you turn it on.")
                .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding()
    }

    private var distanceKm: Double? {
        guard let a = myCoord, let b = partnerCoord else { return nil }
        let la = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let lb = CLLocation(latitude: b.latitude, longitude: b.longitude)
        return la.distance(from: lb) / 1000.0
    }

    private func loadPartner() async {
        partner = try? await APIClient.shared.partnerLocation()
        fitRegion()
        // Keep the widget on the same number the map is showing.
        DistanceSync.publish(km: distanceKm)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Keep the map live while it is open: the partner's pin (and the distance)
    /// follow them without pull-to-refresh.
    private func pollPartner() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard !Task.isCancelled else { return }
            await loadPartner()
        }
    }
}
