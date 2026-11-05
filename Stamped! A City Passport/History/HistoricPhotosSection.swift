//
//  HistoricPhotosSection.swift
//  Stamped! A City Passport
//
//  Old photos of a landmark from every archive (see `OldPhotoSources`), on its page on
//  iPhone and on its card on Vision Pro. A row of thumbnails, each with its own credit;
//  tap one to see it large with its caption, credit and a link to its archive's page.
//
//  Shows nothing at all while loading or when no archive has the landmark.
//

import SwiftUI

struct HistoricPhotosSection: View {
    let building: Building
    let cityName: String
    /// The Library of Congress only covers the US; nil lets the address decide
    var inUnitedStates: Bool? = nil
    /// The Library of Congress's measured drawings, as well as photos
    var includesDrawings = true
    var isHighContrast = false

    @State private var images: [HistoricImage] = []
    @State private var loaded = false
    @State private var selected: HistoricImage?

    // Thumbnails grow with the text size, like the food cards
    @ScaledMetric(relativeTo: .subheadline) private var thumbnailHeight: CGFloat = 140

    var body: some View {
        if !images.isEmpty {
            section
        } else if !loaded {
            // Nothing to show yet: a zero-height view just to run the lookup
            Color.clear
                .frame(height: 0)
                .task(id: building.id) { await load() }
        }
    }

    private func load() async {
        images = await OldPhotoSources.gallery(for: building, cityName: cityName, inUnitedStates: inUnitedStates,
                                               includingDrawings: includesDrawings)
        loaded = true
    }

    private var section: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader(includesDrawings ? "Historic Photos & Drawings" : "Old Photos", systemImage: "photo.on.rectangle.angled", isHighContrast: isHighContrast)

            ScrollView(.horizontal, showsIndicators: false) {
                // Lazy, so thumbnails further along the row load only when scrolled to
                LazyHStack(alignment: .top, spacing: DS.Space.m) {
                    ForEach(images) { image in
                        VStack(alignment: .leading, spacing: DS.Space.xs) {
                            Button {
                                selected = image
                            } label: {
                                HistoricThumbnail(image: image, height: thumbnailHeight, isHighContrast: isHighContrast)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(image.accessibilityText)
                            .accessibilityHint(Text("Shows the image larger"))
                            // Every photo keeps its own credit in view; the large view has it in full
                            Text(verbatim: image.credit)
                                .font(.caption2)
                                .foregroundStyle(isHighContrast ? Color.primary : Color.secondary)
                                .lineLimit(2)
                                .frame(width: thumbnailHeight * 1.3, alignment: .leading)
                        }
                    }
                }
            }
        }
        .sheet(item: $selected) { image in
            HistoricImageViewer(image: image, buildingName: building.name, isHighContrast: isHighContrast)
                // A photo viewer: a big sheet on iPad, so the picture is shown large
                .dsLargeSheet()
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

struct HistoricImageViewer: View {
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
                        // Captions come from the archive itself, usually in English
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
                            Label("View Source", systemImage: "arrow.up.right.square")
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
