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
                            .aspectRatio(contentMode: contentMode)
                            .frame(maxWidth: .infinity)
                            .frame(height: height)
                            .clipped()
                            .accessibilityLabel("Photo of \(building.name)")
                    case .failure:
                        assetFallback
                    case .empty:
                        shimmerPlaceholder
                    @unknown default:
                        assetFallback
                    }
                }
            } else if loaded {
                assetFallback
            } else {
                shimmerPlaceholder
            }
        }
        .frame(height: height)
        .task {
            let summary = await WikimediaService.shared.summary(for: building.name)
            photoURL = summary.photoURL
            loaded = true
        }
    }

    // Shown when Wikipedia has no photo and no asset exists in the catalog
    private var assetFallback: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.slash")
                .font(.system(size: fallbackIconSize))
                .foregroundStyle(.secondary)
            Text("No photo available")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(Color(UIColor.secondarySystemBackground))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No photo available for \(building.name)")
    }

    private var shimmerPlaceholder: some View {
        Rectangle()
            .fill(Color(UIColor.secondarySystemBackground))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .shimmering()
    }
}

// MARK: - Wikipedia description card

struct WikiDescriptionCard: View {
    let building: Building

    @State private var extract: String? = nil
    @State private var expanded = false

    var body: some View {
        Group {
            if let text = extract {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "w.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("From Wikipedia")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text(text)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(expanded ? nil : 4)
                    if !expanded {
                        Button("Read more") { withAnimation(.easeInOut(duration: 0.2)) { expanded = true } }
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .accessibilityLabel("Read more about \(building.name)")
                            .accessibilityHint("Expands the full Wikipedia description")
                    }
                }
                .padding(14)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
        .task {
            let summary = await WikimediaService.shared.summary(for: building.name)
            extract = summary.extract
        }
    }
}
