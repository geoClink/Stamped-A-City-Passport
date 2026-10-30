//
//  BuildingPhotoGallery.swift
//  Stamped! A City Passport
//
//  A swipeable strip of free Wikimedia Commons photos on a building page, each
//  with its author and license (the CC licenses require the credit). Tapping a
//  photo opens it full screen. Shows nothing when there are no extra photos.
//

import SwiftUI

struct BuildingPhotoGallery: View {
    let building: Building
    var isHighContrast = false

    @State private var photos: [WikiGalleryPhoto] = []
    @State private var selectedPhoto: WikiGalleryPhoto? = nil

    // Wider at large text sizes, so the credit under each photo has room
    @ScaledMetric(relativeTo: .caption) private var photoWidth: CGFloat = 240
    @ScaledMetric(relativeTo: .caption) private var photoHeight: CGFloat = 170

    var body: some View {
        Group {
            if !photos.isEmpty {
                VStack(alignment: .leading, spacing: DS.Space.m) {
                    DSSectionHeader("More Photos", systemImage: "photo.on.rectangle.angled", isHighContrast: isHighContrast)

                    // Lazy, so each thumbnail only downloads when it scrolls into view
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: DS.Space.m) {
                            ForEach(photos) { photo in
                                Button {
                                    selectedPhoto = photo
                                } label: {
                                    thumbnail(for: photo)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text("Photo of \(building.name)"))
                                .accessibilityValue(photo.credit)
                                .accessibilityHint(Text("Opens the photo full screen"))
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                }
                .transition(.opacity)
            } else {
                // No photos (yet): an invisible, zero-height view. An empty Group would have
                // nothing on screen to attach .task to, so the photos would never load.
                Color.clear
                    .frame(height: 0)
                    .accessibilityHidden(true)
            }
        }
        .animation(.easeIn(duration: 0.2), value: photos.isEmpty)
        .task(id: building.id) {
            photos = await WikiGalleryService.shared.photos(for: building.name, buildingID: building.id)
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            GalleryFullScreenView(photos: photos, startID: photo.id, buildingName: building.name)
        }
    }

    private func thumbnail(for photo: WikiGalleryPhoto) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            AsyncImage(url: photo.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Image(systemName: "photo.slash")
                        .foregroundStyle(.secondary)
                default:
                    Rectangle()
                        .fill(DS.Palette.cardBackground)
                        .shimmering()
                }
            }
            // Fixed frame so the strip doesn't jump as photos load
            .frame(width: photoWidth, height: photoHeight)
            .background(DS.Palette.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
            )

            Text(photo.credit)
                .font(.caption2)
                .foregroundColor(isHighContrast ? .primary : .secondary)
                .lineLimit(2)
                .frame(width: photoWidth, alignment: .leading)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Full-screen view

/// One photo at a time, swiping sideways to the others, with the full credit and a
/// link to the photo's Commons page underneath.
private struct GalleryFullScreenView: View {
    let photos: [WikiGalleryPhoto]
    let buildingName: String

    @State private var currentID: String?
    @Environment(\.dismiss) private var dismiss

    init(photos: [WikiGalleryPhoto], startID: String, buildingName: String) {
        self.photos = photos
        self.buildingName = buildingName
        _currentID = State(initialValue: startID)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(photos) { photo in
                        page(for: photo)
                            .containerRelativeFrame([.horizontal, .vertical])
                            .id(photo.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentID)

            // Same Done button as Look Around, inside the safe area so it stays tappable
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, DS.Space.l)
                    .padding(.vertical, DS.Space.s)
                    .background(.regularMaterial, in: Capsule())
            }
            .padding(.top, DS.Space.m)
            .padding(.trailing, DS.Space.l)
        }
    }

    private func page(for photo: WikiGalleryPhoto) -> some View {
        VStack(spacing: DS.Space.m) {
            Spacer(minLength: 0)

            AsyncImage(url: photo.largeURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel(Text("Photo of \(buildingName)"))
                case .failure:
                    Image(systemName: "photo.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.7))
                default:
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Spacer(minLength: 0)

            // The full credit, never truncated
            VStack(spacing: DS.Space.xs) {
                let number = (photos.firstIndex(of: photo) ?? 0) + 1
                Text(verbatim: "\(number) / \(photos.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
                    .accessibilityHidden(true)
                Text(photo.credit)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let pageURL = photo.pageURL {
                    Link(destination: pageURL) {
                        Text("View on Wikimedia Commons")
                            .font(.footnote.bold())
                            .foregroundStyle(DS.Palette.accent)
                    }
                    .accessibilityHint(Text("Shows the photo's author and license"))
                }
            }
            .padding(.horizontal, DS.Space.page)
            .padding(.bottom, DS.Space.l)
        }
    }
}
