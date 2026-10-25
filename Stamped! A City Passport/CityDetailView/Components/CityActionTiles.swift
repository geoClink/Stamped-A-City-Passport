//
//  CityActionTiles.swift
//  Stamped! A City Passport
//
//  The quiz, Plan a Trip and (on campuses) Plan a Campus Visit as one row of tiles,
//  instead of three full-width cards stacked down the page. With very large text the
//  tiles become full-width rows, so titles never get squeezed into hyphenated pieces.
//

import SwiftUI

struct CityActionTile: Identifiable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    var iconColor: Color = .adventureOrange
    let accessibilityHint: String
    let action: () -> Void
}

struct CityActionTiles: View {
    let tiles: [CityActionTile]
    let isHighContrast: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title2) private var iconWidth: CGFloat = 32

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: DS.Space.s) {
                ForEach(tiles) { tile in button(for: tile, wide: true) }
            }
        } else {
            HStack(spacing: DS.Space.s) {
                ForEach(tiles) { tile in button(for: tile, wide: false) }
            }
        }
    }

    private func button(for tile: CityActionTile, wide: Bool) -> some View {
        Button {
            HapticManager.shared.trigger(.selection)
            tile.action()
        } label: {
            Group {
                if wide {
                    HStack(spacing: DS.Space.m) {
                        icon(tile)
                        VStack(alignment: .leading, spacing: DS.Space.xs) {
                            title(tile)
                            detail(tile)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(DS.Space.l)
                } else {
                    VStack(alignment: .leading, spacing: DS.Space.s) {
                        icon(tile)
                        Spacer(minLength: 0)
                        title(tile)
                        detail(tile)
                    }
                    .padding(DS.Space.m)
                    .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                }
            }
            .background(isHighContrast ? Color(UIColor.systemBackground) : DS.Palette.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(RoundedButtonStyle())
        .hoverEffect(.lift)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tile.title). \(tile.detail)")
        .accessibilityHint(tile.accessibilityHint)
    }

    private func icon(_ tile: CityActionTile) -> some View {
        Image(systemName: tile.systemImage)
            .font(.title2)
            .foregroundColor(isHighContrast ? .primary : tile.iconColor)
            .frame(width: iconWidth, alignment: .leading)
    }

    private func title(_ tile: CityActionTile) -> some View {
        Text(tile.title)
            .font(.subheadline)
            .fontWeight(isHighContrast ? .black : .semibold)
            .foregroundColor(.primary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func detail(_ tile: CityActionTile) -> some View {
        Text(tile.detail)
            .font(.caption.monospacedDigit())
            .fontWeight(isHighContrast ? .bold : .regular)
            .foregroundColor(isHighContrast ? .primary : .secondary)
            .lineLimit(2)
    }
}
