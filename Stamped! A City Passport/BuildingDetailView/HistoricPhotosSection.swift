//
//  HistoricPhotosSection.swift
//  Stamped! A City Passport
//
//  "Historic Photos & Drawings" on a US landmark's page: survey photos and measured
//  drawings from the Library of Congress (HABS/HAER). A row of thumbnails; tap one to
//  see it large with its caption, credit and a link to the survey on loc.gov.
//
//  Shows nothing at all outside the US, while loading, or when no survey matches.
//

import SwiftUI

struct HistoricPhotosSection: View {
    let building: Building
    let city: CityLocation.City
    var isHighContrast = false

    @State private var images: [HistoricImage] = []
    @State private var loaded = false
    @State private var selected: HistoricImage?
    @State private var browserLink: BrowserLink?

    // Thumbnails grow with the text size, like the food cards
    @ScaledMetric(relativeTo: .subheadline) private var thumbnailHeight: CGFloat = 140

    var body: some View {
        // HABS/HAER only covers the United States (cities and campuses)
        if city.country == .unitedStates {
            if !images.isEmpty {
                section
            } else if !loaded {
                // Nothing to show yet: a zero-height view just to run the lookup
                Color.clear
                    .frame(height: 0)
                    .task(id: building.id) { await load() }
            }
        }
    }

    private func load() async {
        images = await LibraryOfCongressService.shared.images(
            buildingID: building.id,
            name: building.name,
            address: building.address,
            cityName: city.name
        )
        loaded = true
    }

    private var section: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader("Historic Photos & Drawings", systemImage: "photo.on.rectangle.angled", isHighContrast: isHighContrast)

            ScrollView(.horizontal, showsIndicators: false) {
                // Lazy, so thumbnails further along the row load only when scrolled to
                LazyHStack(spacing: DS.Space.m) {
                    ForEach(images) { image in
                        Button {
                            selected = image
                        } label: {
                            HistoricThumbnail(image: image, height: thumbnailHeight, isHighContrast: isHighContrast)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(image.accessibilityText)
                        .accessibilityHint(Text("Shows the image larger"))
                    }
                }
            }

            creditLine
        }
        .sheet(item: $selected) { image in
            HistoricImageViewer(image: image, buildingName: building.name, isHighContrast: isHighContrast)
        }
        .inAppBrowser(item: $browserLink)
    }

    /// "Library of Congress, HABS MO-1140" and a link to the survey. Usually one survey;
    /// a building documented in two lists both credits.
    private var creditLine: some View {
        let credits = images.map(\.credit).reduce(into: [String]()) { list, credit in
            if !list.contains(credit) { list.append(credit) }
        }
        return VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(credits.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(isHighContrast ? Color.primary : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let itemURL = images.first?.itemURL {
                Button {
                    browserLink = BrowserLink(url: itemURL)
                } label: {
                    Label("View on loc.gov", systemImage: "arrow.up.right.square")
                        .font(.caption.bold())
                }
                .foregroundStyle(isHighContrast ? Color.primary : DS.Palette.accent)
            }
        }
    }
}

// MARK: - Thumbnail

private struct HistoricThumbnail: View {
    let image: HistoricImage
    let height: CGFloat
    var isHighContrast = false

    var body: some View {
        // Fixed frame first, so the row doesn't jump as images arrive
        Color.clear
            .frame(width: height * 1.3, height: height)
            .overlay {
                AsyncImage(url: image.thumbnailURL) { phase in
                    switch phase {
                    case .success(let loaded):
                        loaded
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(DS.Palette.cardBackground)
                    default:
                        Rectangle()
                            .fill(DS.Palette.cardBackground)
                            .shimmering()
                    }
                }
            }
            .overlay(alignment: .bottomLeading) {
                if image.isDrawing {
                    Text("Drawing")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, DS.Space.s)
                        .padding(.vertical, DS.Space.xs)
                        .background(.regularMaterial, in: Capsule())
                        .padding(DS.Space.s)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                    .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
    }
}

// MARK: - Large view

private struct HistoricImageViewer: View {
    let image: HistoricImage
    let buildingName: String
    var isHighContrast = false

    @Environment(\.dismiss) private var dismiss
    @State private var browserLink: BrowserLink?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    AsyncImage(url: image.largeURL) { phase in
                        switch phase {
                        case .success(let loaded):
                            loaded
                                .resizable()
                                .scaledToFit()
                                .accessibilityLabel(image.accessibilityText)
                        case .failure:
                            Label("Image unavailable", systemImage: "photo")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 200)
                        default:
                            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                                .fill(DS.Palette.cardBackground)
                                .frame(height: 320)
                                .shimmering()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))

                    VStack(alignment: .leading, spacing: DS.Space.s) {
                        // Captions come from the survey itself, in English
                        if let caption = image.caption {
                            Text(caption)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(image.credit)
                            .font(.footnote)
                            .foregroundStyle(isHighContrast ? Color.primary : Color.secondary)
                        Button {
                            browserLink = BrowserLink(url: image.itemURL)
                        } label: {
                            Label("View on loc.gov", systemImage: "arrow.up.right.square")
                                .font(.subheadline.bold())
                        }
                        .foregroundStyle(isHighContrast ? Color.primary : DS.Palette.accent)
                    }
                }
                .padding(DS.Space.page)
            }
            .background(DS.Palette.pageBackground)
            .navigationTitle(buildingName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .inAppBrowser(item: $browserLink)
        #if os(macOS)
        // A Mac sheet takes its content's size; give the picture room
        .frame(minWidth: 560, idealWidth: 720, minHeight: 600)
        #endif
    }
}

// MARK: - VoiceOver

private extension HistoricImage {
    /// The survey's caption, or what kind of picture it is when there's none.
    var accessibilityText: String {
        if let caption { return caption }
        return isDrawing
            ? NSLocalizedString("Measured drawing", comment: "Historic Photos section, VoiceOver: a HABS architectural drawing with no caption")
            : NSLocalizedString("Historic photo", comment: "Historic Photos section, VoiceOver: a HABS survey photo with no caption")
    }
}
