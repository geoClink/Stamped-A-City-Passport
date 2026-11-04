import SwiftUI

// MARK: - City Stamp Card Design

/// The picture shared from a city (or campus) stamp. Same 360x500 size and fixed point
/// sizes as PassportCard, for the same reason: Dynamic Type would push content off the card.
struct CityStampShareCard: View {
    let city: CityLocation.City
    let stampedCount: Int
    let date: String

    static let cardWidth: CGFloat = 360
    static let cardHeight: CGFloat = 500

    private var landmarksLine: String {
        String(format: NSLocalizedString("%1$d of %2$d landmarks stamped",
                                         comment: "City stamp share picture; %1$d is landmarks visited, %2$d is landmarks in the city"),
               stampedCount, city.buildings.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            ShareCardBrandBar()
                .background(DS.Palette.accent)

            Spacer(minLength: 0)

            // The same stamp the app shows, held still for the picture
            PassportStampView(
                cityName: city.name,
                dateCompleted: date,
                funFact: "Master of \(city.name) Architecture",
                animatesIn: false
            )
            .padding(.horizontal, DS.Space.section)

            Spacer(minLength: 0)

            Text(landmarksLine.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DS.Palette.accent)
                .tracking(2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, DS.Space.l)
                .padding(.bottom, DS.Space.l)

            ShareCardFooter()
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .background(Color.white)
        // A printed card: always light, at the standard text size, whatever the phone is set to
        .environment(\.colorScheme, .light)
        .dynamicTypeSize(.large)
    }
}
