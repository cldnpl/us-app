import SwiftUI
import MapKit

/// A card showing both partners on a map plus the distance connector.
/// Appears on Home only when both people are sharing their location.
struct DistanceMapCard: View {
    let mine: CLLocationCoordinate2D
    let partner: CLLocationCoordinate2D
    let myName: String
    let partnerName: String
    let km: Double

    var body: some View {
        VStack(spacing: 14) {
            map
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .allowsHitTesting(false)
            DistanceConnector(myName: myName, partnerName: partnerName, km: km)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }

    private var pins: [DistancePin] {
        [DistancePin(name: myName, coordinate: mine),
         DistancePin(name: partnerName, coordinate: partner)]
    }

    private var region: MKCoordinateRegion {
        let midLat = (mine.latitude + partner.latitude) / 2
        let midLng = (mine.longitude + partner.longitude) / 2
        let latDelta = abs(mine.latitude - partner.latitude) * 1.8 + 0.04
        let lngDelta = abs(mine.longitude - partner.longitude) * 1.8 + 0.04
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: midLat, longitude: midLng),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta))
    }

    private var map: some View {
        Map(coordinateRegion: .constant(region), annotationItems: pins) { pin in
            MapAnnotation(coordinate: pin.coordinate) {
                VStack(spacing: 2) {
                    Image(systemName: "heart.circle.fill")
                        .font(.title2).foregroundStyle(Theme.rose)
                        .background(Circle().fill(.white).padding(2))
                    Text(pin.name)
                        .font(.caption2).bold()
                        .lineLimit(1)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.white, in: Capsule())
                }
            }
        }
    }
}

/// "You ──♥── Alex" with the km distance. The connecting line grows longer the
/// farther apart the two people are.
struct DistanceConnector: View {
    let myName: String
    let partnerName: String
    let km: Double

    var body: some View {
        VStack(spacing: 10) {
            Text(distanceText)
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(Theme.rose)
            HStack(spacing: 8) {
                Text(myName).font(.subheadline.weight(.semibold))
                    .lineLimit(1).minimumScaleFactor(0.7)
                lineWithHeart
                Text(partnerName).font(.subheadline.weight(.semibold))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var distanceText: String {
        if km < 1 { return "Less than 1 km apart 💜" }
        return "\(Int(km.rounded())) km apart"
    }

    /// Line length scales with distance (with a cap so it always fits the card).
    private var lineWithHeart: some View {
        let lineWidth = min(170, CGFloat(38 + sqrt(km) * 9))
        return ZStack {
            DashedLine()
                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 5]))
                .foregroundStyle(Theme.rose.opacity(0.65))
                .frame(width: lineWidth, height: 2)
            Image(systemName: "heart.fill")
                .font(.footnote)
                .foregroundStyle(Theme.rose)
                .padding(4)
                .background(.background, in: Circle())
        }
        .accessibilityHidden(true)
    }
}

/// Map annotation model for the two partners (named to avoid MapKit's
/// deprecated `MapPin` type).
private struct DistancePin: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

/// A single horizontal line, used for the dashed distance connector.
private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}
