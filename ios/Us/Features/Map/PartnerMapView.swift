import SwiftUI
import MapKit

struct MapPin: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
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
                        Image(systemName: "heart.circle.fill")
                            .font(.title).foregroundStyle(Theme.rose)
                            .background(Circle().fill(.white).padding(4))
                        Text(item.name)
                            .font(.caption2).bold()
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.white, in: Capsule())
                    }
                }
            }
            .ignoresSafeArea(edges: .top)

            controlCard
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadPartner() }
        .refreshable { await loadPartner() }
        .onAppear { fitRegion() }
        .onReceive(location.$currentLocation) { _ in fitRegion() }
    }

    // MARK: - Coordinates & pins

    private var myName: String {
        #if DEBUG
        return session.user?.displayName ?? "Claudia"
        #else
        return session.user?.displayName ?? "You"
        #endif
    }
    private var partnerName: String {
        let real = partner?.partnerName ?? session.partner?.displayName
        #if DEBUG
        // Test fallback so the sample map reads "Elbek".
        if real == nil || real?.isEmpty == true || real == "Partner" { return "Elbek" }
        #endif
        return real ?? "Partner"
    }

    private var myCoord: CLLocationCoordinate2D? {
        if location.isSharing, let c = location.currentLocation?.coordinate { return c }
        #if DEBUG
        return CLLocationCoordinate2D(latitude: 40.8518, longitude: 14.2681) // Naples (test)
        #else
        return nil
        #endif
    }

    private var partnerCoord: CLLocationCoordinate2D? {
        if let p = partner, p.sharing, let lat = p.lat, let lng = p.lng {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        #if DEBUG
        return CLLocationCoordinate2D(latitude: 41.2995, longitude: 69.2401) // Tashkent (test)
        #else
        return nil
        #endif
    }

    private var annotations: [MapPin] {
        var pins: [MapPin] = []
        if let m = myCoord { pins.append(MapPin(name: myName, coordinate: m)) }
        if let pc = partnerCoord { pins.append(MapPin(name: partnerName, coordinate: pc)) }
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
                Text("\(Int(km.rounded())) km apart")
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(Theme.rose)
            }
            if let p = partner, p.sharing {
                Label("\(partnerName) is sharing 💜", systemImage: "location.fill")
                    .font(.subheadline)
            } else {
                Text("\(partnerName) isn't sharing their location right now.")
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
                Text("Enable location access in Settings to share.")
                    .font(.caption).foregroundStyle(.red)
            }
            Text("Sharing is off unless you turn it on, and stops the moment you toggle it off.")
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
    }
}
