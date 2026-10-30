//
//  PlaceThumbnail.swift
//  Stamped! A City Passport
//
//  The picture at the top of a restaurant ("Local Flavors") or hotel
//  ("Stays Near Here") card: Apple's Look Around street-level snapshot of the
//  place when Apple has imagery there, otherwise an icon for the kind of place.
//  Snapshots load only when the card scrolls into view and are kept in memory,
//  so scrolling back and forth doesn't fetch them again.
//

import SwiftUI
import MapKit

struct PlaceThumbnail: View {
    let mapItem: MKMapItem
    let category: MKPointOfInterestCategory?
    let height: CGFloat
    var isHighContrast = false

    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var snapshot: UIImage?
    /// The width the card gives us; the snapshot is made at this size.
    @State private var width: CGFloat = 0

    @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = 26

    /// Restarts the load when the place or the thumbnail's size changes.
    private struct LoadID: Hashable {
        let key: String
        let width: CGFloat
    }

    private var cacheKey: String {
        PlaceSnapshotCache.key(name: mapItem.name, coordinate: mapItem.displayCoordinate)
    }

    var body: some View {
        let kind = PlaceThumbnailKind(category: category)

        // The icon is always drawn, so `.task` always runs (an empty view never
        // runs its task). The snapshot covers it once it arrives.
        RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
            .fill(kind.background(isHighContrast: isHighContrast))
            .overlay {
                Image(systemName: kind.symbol)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(kind.tint(isHighContrast: isHighContrast))
            }
            .overlay {
                if let snapshot {
                    Image(uiImage: snapshot)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                width = newWidth
            }
            // Runs when the card scrolls into view; SwiftUI cancels it when it scrolls away
            .task(id: LoadID(key: cacheKey, width: width)) {
                await loadSnapshot()
            }
            // Decorative: the card already says the place's name
            .accessibilityHidden(true)
    }

    private func loadSnapshot() async {
        guard width > 0, height > 0 else { return }

        let cache = PlaceSnapshotCache.shared
        if let cached = cache.entry(for: cacheKey) {
            snapshot = cached.image
            return
        }
        // A new place: don't keep showing the last place's picture
        snapshot = nil

        let size = CGSize(width: width, height: height)
        let result = await PlaceSnapshotLoader.snapshot(of: mapItem.displayCoordinate, size: size, scale: displayScale)
        // Scrolled away before it finished: try again next time instead of caching
        guard !Task.isCancelled else { return }

        switch result {
        case .image(let image):
            cache.store(image, for: cacheKey, size: size, scale: displayScale)
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                snapshot = image
            }
        case .noImagery:
            // Remember there's nothing here, so we don't ask Apple again
            cache.store(nil, for: cacheKey, size: .zero, scale: displayScale)
        case .failed:
            // Probably offline; keep the icon and try again when the card comes back
            break
        }
    }
}

// MARK: - Icon per kind of place

/// The fallback icon and its color for each kind of place.
enum PlaceThumbnailKind: Equatable {
    case restaurant, cafe, bakery, bar, brewery, winery, market, hotel, other

    init(category: MKPointOfInterestCategory?) {
        switch category {
        case .restaurant?: self = .restaurant
        case .cafe?:       self = .cafe
        case .bakery?:     self = .bakery
        case .nightlife?:  self = .bar
        case .brewery?:    self = .brewery
        case .winery?:     self = .winery
        case .foodMarket?: self = .market
        case .hotel?:      self = .hotel
        default:           self = .other
        }
    }

    var symbol: String {
        switch self {
        case .restaurant: "fork.knife"
        case .cafe:       "cup.and.saucer.fill"
        // SF Symbols has no croissant; the cake is the closest bakery symbol
        case .bakery:     "birthday.cake.fill"
        case .bar:        "wineglass.fill"
        case .brewery:    "mug.fill"
        case .winery:     "wineglass"
        case .market:     "basket.fill"
        case .hotel:      "bed.double.fill"
        case .other:      "mappin"
        }
    }

    /// System colors, so each one adjusts itself for light and dark mode.
    var color: Color {
        switch self {
        case .restaurant: .orange
        case .cafe:       .brown
        case .bakery:     .pink
        case .bar:        .purple
        case .brewery:    .yellow
        case .winery:     .red
        case .market:     .green
        case .hotel:      .indigo
        case .other:      .gray
        }
    }

    func tint(isHighContrast: Bool) -> Color {
        isHighContrast ? .primary : color
    }

    func background(isHighContrast: Bool) -> Color {
        isHighContrast ? Color.primary.opacity(0.1) : color.opacity(0.15)
    }
}

// MARK: - Loading and caching

/// Asks Apple for a Look Around scene at the place, then renders a still picture of it.
enum PlaceSnapshotLoader {
    enum Outcome {
        case image(UIImage)
        /// Apple has no street-level imagery here
        case noImagery
        /// Network error or cancelled
        case failed
    }

    static func snapshot(of coordinate: CLLocationCoordinate2D, size: CGSize, scale: CGFloat) async -> Outcome {
        let request = MKLookAroundSceneRequest(coordinate: coordinate)
        let scene: MKLookAroundScene?
        do {
            // Apple's async calls don't stop on their own when the task is cancelled,
            // so the cancellation handler stops the request too.
            scene = try await withTaskCancellationHandler {
                try await request.scene
            } onCancel: {
                request.cancel()
            }
        } catch {
            return .failed
        }
        guard let scene else { return .noImagery }

        let options = MKLookAroundSnapshotter.Options()
        options.size = size
        #if os(iOS)
        // Render at the screen's pixel density (the Mac picks it on its own)
        options.traitCollection = UITraitCollection(displayScale: scale)
        #endif
        let snapshotter = MKLookAroundSnapshotter(scene: scene, options: options)
        do {
            let result = try await withTaskCancellationHandler {
                try await snapshotter.snapshot
            } onCancel: {
                snapshotter.cancel()
            }
            return .image(result.image)
        } catch {
            return .failed
        }
    }
}

/// Snapshots kept in memory by place. NSCache throws old ones away on its own
/// when it passes its limits or the device runs low on memory.
final class PlaceSnapshotCache {
    static let shared = PlaceSnapshotCache()

    /// A class wrapper, because NSCache only stores objects. `image` is nil when
    /// Apple has no imagery for the place.
    final class Entry {
        let image: UIImage?
        init(image: UIImage?) { self.image = image }
    }

    private let cache = NSCache<NSString, Entry>()

    init() {
        cache.countLimit = 100
        // About 40 MB of decoded pixels
        cache.totalCostLimit = 40 * 1024 * 1024
    }

    /// The same place always gets the same key. Coordinates are rounded to
    /// about a meter so tiny differences between searches still match.
    static func key(name: String?, coordinate: CLLocationCoordinate2D) -> String {
        let latitude = String(format: "%.5f", coordinate.latitude)
        let longitude = String(format: "%.5f", coordinate.longitude)
        return "\(name ?? "")|\(latitude),\(longitude)"
    }

    func entry(for key: String) -> Entry? {
        cache.object(forKey: key as NSString)
    }

    func store(_ image: UIImage?, for key: String, size: CGSize, scale: CGFloat) {
        // 4 bytes per pixel once the image is decoded
        let cost = Int(size.width * scale * size.height * scale * 4)
        cache.setObject(Entry(image: image), forKey: key as NSString, cost: cost)
    }
}
