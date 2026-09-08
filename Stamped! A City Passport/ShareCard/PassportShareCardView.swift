import SwiftUI

// MARK: - Share Sheet

struct PassportShareCardView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var progress = GlobalProgressManager.shared
    @StateObject private var cityVM = CityViewModel()

    @State private var renderedImage: Image?

    private var cities: [CityLocation.City] { cityVM.allCities }

    private var visitedCities: [CityLocation.City] {
        cities.filter { city in
            city.buildings.contains { progress.visitedIDs.contains($0.id) }
        }
    }

    private var countryCount: Int {
        Set(visitedCities.map { $0.country }).count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    cardPreview
                    shareButton
                }
                .padding(.vertical, 24)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Share Passport")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adventureOrange)
                }
            }
        }
        .task { await renderCard() }
    }

    // MARK: - Card Preview

    private var cardPreview: some View {
        PassportCard(
            stampCount: progress.visitedIDs.count,
            cityCount: visitedCities.count,
            countryCount: countryCount,
            visitedCities: visitedCities
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
        .padding(.horizontal, 24)
    }

    // MARK: - Share Button

    @ViewBuilder
    private var shareButton: some View {
        if let image = renderedImage {
            ShareLink(
                item: image,
                preview: SharePreview("My Stamped! Passport", image: image)
            ) {
                Label("Share Passport", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.adventureOrange)
                    .cornerRadius(14)
                    .padding(.horizontal, 24)
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
        }
    }

    // MARK: - Render

    @MainActor
    private func renderCard() async {
        let card = PassportCard(
            stampCount: progress.visitedIDs.count,
            cityCount: visitedCities.count,
            countryCount: countryCount,
            visitedCities: visitedCities
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        if let uiImage = renderer.uiImage {
            renderedImage = Image(uiImage: uiImage)
        }
    }
}

// MARK: - Passport Card Design

struct PassportCard: View {
    let stampCount: Int
    let cityCount: Int
    let countryCount: Int
    let visitedCities: [CityLocation.City]

    static let orange = Color.adventureOrange
    static let cardWidth: CGFloat = 360
    static let cardHeight: CGFloat = 500

    private var displayCities: [CityLocation.City] { Array(visitedCities.prefix(14)) }
    private var extraCount: Int { max(0, visitedCities.count - 14) }

    var body: some View {
        VStack(spacing: 0) {
            topBand
            bottomSection
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }

    // MARK: - Orange top band

    private var topBand: some View {
        VStack(spacing: 0) {
            // App bar
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("STAMPED!")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.black)
                            .foregroundStyle(.white)
                        Text("A CITY PASSPORT")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                            .tracking(2)
                    }
                }
                Spacer()
                Text(Date().formatted(.dateTime.month(.abbreviated).year()))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 18)

            // Big stamp count
            VStack(spacing: 6) {
                Text("\(stampCount)")
                    .font(.system(size: 88, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)

                Text("STAMPS COLLECTED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .tracking(3)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 22)

            // Cities / countries row
            HStack(spacing: 0) {
                statBlock(value: cityCount, label: "CITIES")
                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 1, height: 28)
                statBlock(value: countryCount, label: "COUNTRIES")
            }
            .padding(.bottom, 22)
        }
        .background(Self.orange)
    }

    private func statBlock(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - White bottom section with city tags

    private var bottomSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !visitedCities.isEmpty {
                Text("CITIES VISITED")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Self.orange)
                    .tracking(3)
                    .padding(.top, 16)
                    .padding(.horizontal, 20)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 74, maximum: 120), spacing: 6)],
                    spacing: 6
                ) {
                    ForEach(displayCities) { city in
                        Text(city.name)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Self.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Self.orange.opacity(0.1))
                            .cornerRadius(5)
                            .lineLimit(1)
                    }
                    if extraCount > 0 {
                        Text("+\(extraCount) more")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Self.orange.opacity(0.6))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Self.orange.opacity(0.05))
                            .cornerRadius(5)
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer(minLength: 0)

            // Footer
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption2)
                    .foregroundStyle(Self.orange.opacity(0.4))
                Text("stamped-app.com")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Self.orange.opacity(0.4))
                    .tracking(1)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
