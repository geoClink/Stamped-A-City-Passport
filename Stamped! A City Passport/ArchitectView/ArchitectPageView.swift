//
//  ArchitectPageView.swift
//  Stamped! A City Passport
//
//  An architect's page: their photo (when Wikipedia has a free one), a short bio,
//  and every landmark of theirs in the app, across all cities and campuses.
//  Opened from the "Designed by" line on a building page (`ArchitectLink`).
//

import SwiftUI

// MARK: - Strings

extension L {
    enum Architect {
        static let openHint = String(localized: "architect.openHint")
        static let fromWikipedia = String(localized: "architect.fromWikipedia")
        static let readOnWikipedia = String(localized: "architect.readOnWikipedia")
        static let photoCredit = String(localized: "architect.photoCredit")
    }
}

// MARK: - "Designed by" link

/// The "Designed by …" line under a building's name. With one architect it opens
/// their page; with several ("I.M. Pei & Henry N. Cobb") it asks which one.
/// Plain text when there's no one to link to ("Traditional / Unknown").
struct ArchitectLink: View {
    let building: Building
    var isHighContrast = false

    @State private var openArchitect: ArchitectName? = nil

    var body: some View {
        if let architect = building.knownArchitect {
            let architects = ArchitectIndex.architects(of: building)
            Group {
                if architects.count == 1 {
                    Button { openArchitect = architects[0] } label: { linkLabel(architect) }
                } else if architects.count > 1 {
                    Menu {
                        ForEach(architects) { name in
                            Button(name.displayName) { openArchitect = name }
                        }
                    } label: { linkLabel(architect) }
                } else {
                    Text(L.Building.designedBy(architect))
                        .font(.subheadline.italic())
                        .foregroundColor(isHighContrast ? .primary : .secondary)
                }
            }
            .buttonStyle(.plain)
            .navigationDestination(item: $openArchitect) { name in
                ArchitectPageView(architect: name)
            }
        }
    }

    /// Accent colour and a chevron, so the line reads as something you can tap
    private func linkLabel(_ architect: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.xs) {
            Text(L.Building.designedBy(architect))
                .font(.subheadline.italic())
                .multilineTextAlignment(.leading)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .accessibilityHidden(true)
        }
        .foregroundColor(isHighContrast ? .primary : DS.Palette.accent)
        .underline(isHighContrast)
        .contentShape(Rectangle())
        .accessibilityHint(L.Architect.openHint)
    }
}

// MARK: - Architect page

struct ArchitectPageView: View {
    let architect: ArchitectName

    @Environment(\.colorSchemeContrast) var contrast
    @AppStorage("high_contrast_mode") var appHighContrast = false
    @ObservedObject private var progressManager = GlobalProgressManager.shared

    @State private var summary: ArchitectSummary? = nil
    @State private var isLoading = true

    // The portrait grows with the text size, like the rest of the page
    @ScaledMetric(relativeTo: .largeTitle) private var photoWidth: CGFloat = 120

    var isHighContrast: Bool { contrast == .increased || appHighContrast }

    private var landmarks: [(building: Building, city: CityLocation.City)] {
        ArchitectIndex.landmarks(by: architect)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.section) {
                header
                bioSection
                landmarksSection
            }
            .dsPageMargin()
            .padding(.top, DS.Space.l)
            .padding(.bottom, DS.Space.section)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(DS.Palette.pageBackground)
        .navigationTitle(architect.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            summary = await ArchitectWikiService.shared.summary(for: architect.displayName)
            isLoading = false
        }
    }

    // MARK: Header

    /// The portrait (only when Wikipedia has one) beside the name
    private var header: some View {
        HStack(alignment: .center, spacing: DS.Space.l) {
            if let url = summary?.photoURL {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            DS.Palette.cardBackground
                        }
                    }
                    .frame(width: photoWidth, height: photoWidth * 1.25)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                            .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
                    )
                    .accessibilityLabel("Photo of \(architect.displayName)")
                    // Images from the summary endpoint are hosted on Commons
                    Text(L.Architect.photoCredit)
                        .font(.caption2)
                        .foregroundColor(isHighContrast ? .primary : .secondary)
                        .frame(width: photoWidth, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity)
            }
            Text(architect.displayName)
                .font(.system(.largeTitle, design: .serif))
                .fontWeight(.bold)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .animation(.easeIn(duration: 0.2), value: summary?.photoURL)
    }

    // MARK: Bio

    /// The opening of the Wikipedia article, credited the same way as building pages.
    /// Nothing at all when no article describes this architect.
    @ViewBuilder
    private var bioSection: some View {
        if isLoading {
            // Reserve space so the list doesn't jump when the bio arrives
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.Palette.cardBackground)
                .frame(height: 90)
                .shimmering()
        } else if let summary {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "w.circle.fill")
                        .font(.caption)
                    Text(L.Architect.fromWikipedia)
                        .font(.caption2.monospaced().weight(.semibold))
                }
                .foregroundColor(isHighContrast ? .primary : .secondary)
                Text(summary.extract)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let articleURL = summary.articleURL {
                    Link(destination: articleURL) {
                        Label(L.Architect.readOnWikipedia, systemImage: "arrow.up.right.square")
                            .font(.caption.bold())
                            .foregroundColor(isHighContrast ? .primary : DS.Palette.accent)
                    }
                }
            }
            .dsCard(isHighContrast: isHighContrast)
            .transition(.opacity)
        }
    }

    // MARK: Landmarks

    private var landmarksSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader(title: "architect.landmarks", systemImage: "building.columns.fill", isHighContrast: isHighContrast) {
                Text("\(landmarks.count)")
                    .monospacedDigit()
            }
            VStack(spacing: isHighContrast ? DS.Space.m : 0) {
                ForEach(landmarks, id: \.building.id) { landmark in
                    NavigationLink(destination: ArchitectLandmarkDetail(building: landmark.building, city: landmark.city)) {
                        ArchitectLandmarkRow(
                            building: landmark.building,
                            cityName: landmark.city.name,
                            isVisited: progressManager.visitedIDs.contains(landmark.building.id),
                            isHighContrast: isHighContrast
                        )
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.highlight)

                    if !isHighContrast && landmark.building.id != landmarks.last?.building.id {
                        Divider().padding(.leading, 60)
                            .accessibilityHidden(true)
                    }
                }
            }
            .dsCard(padding: isHighContrast ? DS.Space.m : 0, isHighContrast: isHighContrast)
        }
    }
}

// MARK: - Landmark row

/// One landmark on an Architect page: stamped or not, its name, and where it is.
/// Like `LandmarkRow`, but the subtitle is the city (every row has the same architect).
private struct ArchitectLandmarkRow: View {
    let building: Building
    let cityName: String
    let isVisited: Bool
    var isHighContrast = false

    var body: some View {
        HStack(spacing: DS.Space.l) {
            // Orange once stamped, gray until then, as in the city's landmark list
            Image(systemName: isVisited ? "checkmark.seal.fill" : "mappin.circle.fill")
                .font(.title)
                .foregroundColor(isHighContrast ? .primary : (isVisited ? DS.Palette.accent : Color(UIColor.systemGray3)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text(building.name)
                    .font(isHighContrast ? .headline.bold() : .headline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(building.hasKnownYear ? "\(cityName) · \(String(building.yearBuilt))" : cityName)
                    .font(.caption)
                    .foregroundColor(isHighContrast ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DS.Space.s)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundColor(isHighContrast ? .primary : .secondary)
                .accessibilityHidden(true)
        }
        .padding(DS.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isVisited ? "Visited, \(building.name)" : "Not visited, \(building.name)")
        .accessibilityValue(cityName)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Building page from any city

/// A building page needs a view model for the building's own city, which may not be the
/// city the visitor came from. Like My Trips' city trips, this view makes one and keeps it.
private struct ArchitectLandmarkDetail: View {
    let building: Building
    // @StateObject creates the view model once (only when this page opens) and keeps it
    @StateObject private var viewModel: CityDetailViewModel

    init(building: Building, city: CityLocation.City) {
        self.building = building
        _viewModel = StateObject(wrappedValue: CityDetailViewModel(city: city))
    }

    var body: some View {
        BuildingDetailView(building: building, viewModel: viewModel)
    }
}

#Preview {
    NavigationStack {
        ArchitectPageView(architect: ArchitectName(key: "herzog & de meuron", displayName: "Herzog & de Meuron"))
    }
}
