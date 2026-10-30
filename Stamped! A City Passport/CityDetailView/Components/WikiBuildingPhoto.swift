//
//  WikiBuildingPhoto.swift
//  Stamped! A City Passport
//
//  Shows the Wikipedia CC-licensed photo for a building.
//  Falls back to the asset catalog image if Wikipedia has nothing.
//

import SwiftUI

struct WikiBuildingPhoto: View {
    let building: Building
    let height: CGFloat
    var contentMode: ContentMode = .fill  // .fit shows full image; .fill crops to fill frame
    /// Replaces "Photo of <name>" for VoiceOver. The quiz uses this so the label
    /// doesn't give away the answer.
    var accessibilityLabelText: String? = nil
    /// Called when there's no photo to show (none on Wikipedia, or it failed to load)
    var onUnavailable: (() -> Void)? = nil

    @State private var photoURL: URL? = nil
    @State private var loaded = false

    @ScaledMetric(relativeTo: .largeTitle) private var fallbackIconSize: CGFloat = 44

    var body: some View {
        ZStack {
            if let url = photoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: height)
                            .clipped()
                            .accessibilityLabel(accessibilityLabelText ?? String(localized: "Photo of \(building.name)"))
                    case .failure:
                        assetFallback
                    case .empty:
                        shimmerPlaceholder
                    @unknown default:
                        assetFallback
                    }
                }
                // Frame on AsyncImage itself prevents layout shift when image loads
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipped()
            } else if loaded {
                assetFallback
            } else {
                shimmerPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .task {
            let summary = await WikimediaService.shared.summary(for: building.name, buildingID: building.id)
            photoURL = summary.photoURL
            loaded = true
        }
    }

    // Shown when Wikipedia has no photo and no asset exists in the catalog
    private var assetFallback: some View {
        VStack(spacing: DS.Space.s) {
            Image(systemName: "photo.slash")
                .font(.system(size: fallbackIconSize))
                .foregroundStyle(.secondary)
            Text("No photo available")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(DS.Palette.cardBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText == nil ? String(localized: "No photo available for \(building.name)") : String(localized: "No photo available"))
        .onAppear { onUnavailable?() }
    }

    private var shimmerPlaceholder: some View {
        Rectangle()
            .fill(DS.Palette.cardBackground)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .shimmering()
    }
}

// MARK: - Wikipedia description card

struct WikiDescriptionCard: View {
    let building: Building
    var isHighContrast = false

    @State private var extract: String? = nil
    @State private var isLoading = true
    @State private var expanded = false

    var body: some View {
        Group {
            if isLoading {
                // Reserve space so the layout doesn't shift when content loads
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(DS.Palette.cardBackground)
                    .frame(height: 90)
                    .shimmering()
            } else if let text = extract {
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    HStack(spacing: DS.Space.xs) {
                        Image(systemName: "w.circle.fill")
                            .font(.caption)
                        Text("From Wikipedia")
                            .font(.caption2.monospaced().weight(.semibold))
                    }
                    .foregroundColor(isHighContrast ? .primary : .secondary)
                    Text(text)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(expanded ? nil : 4)
                        .fixedSize(horizontal: false, vertical: true)
                    if !expanded {
                        Button("Read more") { withAnimation(.easeInOut(duration: 0.2)) { expanded = true } }
                            .font(.caption.bold())
                            .foregroundColor(isHighContrast ? .primary : DS.Palette.accent)
                            .accessibilityLabel("Read more about \(building.name)")
                            .accessibilityHint("Expands the full Wikipedia description")
                    }
                }
                .dsCard(isHighContrast: isHighContrast)
                .transition(.opacity)
            }
            // If loaded and no extract: render nothing (no reserved space needed)
        }
        .animation(.easeIn(duration: 0.2), value: isLoading)
        .task {
            let summary = await WikimediaService.shared.summary(for: building.name, buildingID: building.id)
            extract = summary.extract
            isLoading = false
        }
    }
}
