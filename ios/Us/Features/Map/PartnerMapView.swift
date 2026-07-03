import SwiftUI
import MapKit

struct MapPin: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

struct PartnerMapView: View {
    @StateObject private var location = LocationManager.shared

    @State private var partner: PartnerLocation?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 80, longitudeDelta: 80)
    )

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(coordinateRegion: $region, annotationItems: annotations) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    VStack(spacing: 2) {
                        Image(systemName: "heart.circle.fill")
                            .font(.title).foregroundStyle(Theme.coral)
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
    }

    private var annotations: [MapPin] {
        if let p = partner, p.sharing, let lat = p.lat, let lng = p.lng {
            return [MapPin(name: p.partnerName ?? "Partner",
                           coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))]
        }
        return []
    }

    private var controlCard: some View {
        VStack(spacing: 12) {
            if let p = partner, p.sharing {
                Label("\(p.partnerName ?? "Your partner") is sharing 💜", systemImage: "location.fill")
                    .font(.subheadline)
            } else {
                Text("Your partner isn't sharing their location right now.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Toggle(isOn: Binding(
                get: { location.isSharing },
                set: { $0 ? location.startSharing() : location.stopSharing() }
            )) {
                Text(location.isSharing ? "Sharing my location" : "Share my location")
            }
            .tint(Theme.coral)

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

    private func loadPartner() async {
        guard let p = try? await APIClient.shared.partnerLocation() else { return }
        partner = p
        if p.sharing, let lat = p.lat, let lng = p.lng {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
    }
}
