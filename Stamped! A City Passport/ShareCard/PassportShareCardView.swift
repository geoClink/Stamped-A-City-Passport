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

    static let gold = Color(red: 0.85, green: 0.65, blue: 0.13)
    static let darkBg = Color(red: 0.11, green: 0.13, blue: 0.17)
    static let cardWidth: CGFloat = 360
    static let cardHeight: CGFloat = 500

    private var displayCities: [CityLocation.City] {
        Array(visitedCities.prefix(14))
    }

    private var extraCount: Int {
        max(0, visitedCities.count - 14)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            dividerLine
            stampCountSection
            statRow
            if !visitedCities.isEmpty {
                dividerLine
                cityTagsSection
            }
            Spacer(minLength: 0)
            footer
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .background(Self.darkBg)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "globe.europe.africa.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Self.gold)

            VStack(alignment: .leading, spacing: 1) {
                Text("STAMPED!")
                    .font(.system(.title3, design: .serif))
                    .fontWeight(.bold)
                    .foregroundStyle(Self.gold)
                Text("A CITY PASSPORT")
                    .font(.system(size: 8, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(Self.gold.opacity(0.6))
                    .tracking(3)
            }

            Spacer()

            Text("№ \(passportNumber)")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(Self.gold.opacity(0.4))
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: Stamp Count

    private var stampCountSection: some View {
        VStack(spacing: 4) {
            Text("\(stampCount)")
                .font(.system(size: 76, design: .serif))
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text("STAMPS COLLECTED")
                .font(.system(size: 10, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(Self.gold)
                .tracking(4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: Stat Row

    private var statRow: some View {
        HStack(spacing: 0) {
            statPill(value: cityCount, label: "CITIES")
            Rectangle()
                .fill(Self.gold.opacity(0.25))
                .frame(width: 1, height: 28)
            statPill(value: countryCount, label: "COUNTRIES")
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 16)
    }

    private func statPill(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(.title2, design: .serif))
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(Self.gold.opacity(0.7))
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: City Tags

    private var cityTagsSection: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 72, maximum: 120), spacing: 5)],
            spacing: 5
        ) {
            ForEach(displayCities) { city in
                Text(city.name)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Self.gold)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Self.gold.opacity(0.12))
                    .cornerRadius(3)
                    .lineLimit(1)
            }
            if extraCount > 0 {
                Text("+\(extraCount) more")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Self.gold.opacity(0.5))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Self.gold.opacity(0.06))
                    .cornerRadius(3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Text(Date().formatted(.dateTime.month(.wide).year()).uppercased())
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(Self.gold.opacity(0.4))
                .tracking(2)
            Spacer()
            Text("STAMPED! APP")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(Self.gold.opacity(0.4))
                .tracking(2)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
    }

    // MARK: Helpers

    private var dividerLine: some View {
        Rectangle()
            .fill(Self.gold.opacity(0.2))
            .frame(height: 1)
            .padding(.horizontal, 20)
    }

    // Deterministic "passport number" from stamp count — purely decorative
    private var passportNumber: String {
        String(format: "%06d", (stampCount * 739 + 100001) % 999999)
    }
}
