//
//  CityHeroHeader.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//
//  The top of a city or campus page: a photo with the name over it, then a row of
//  facts (progress, rank, conference) and the Wikipedia introduction.
//

import SwiftUI

struct CityHeroHeader: View {
    let city: CityLocation.City
    let progress: Double
    let isHighContrast: Bool
    let masteryTier: String

    @State private var cityBlurb: String? = nil
    @State private var photoURL: URL? = nil
    @State private var isExpanded: Bool = false
    @ScaledMetric(relativeTo: .largeTitle) private var photoHeight: CGFloat = 260
    @ScaledMetric(relativeTo: .caption2) private var ringSize: CGFloat = 48
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var accent: Color {
        isHighContrast ? .primary : (city.stampColor(darkMode: colorScheme == .dark) ?? DS.Palette.accent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.l) {
            photoWithTitle
            facts
            if let blurb = cityBlurb {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text(blurb)
                        .font(.subheadline)
                        .foregroundColor(isHighContrast ? .primary : .secondary)
                        .lineLimit(isExpanded ? nil : 3)
                    Button {
                        withAnimation(DS.Motion.quick) { isExpanded.toggle() }
                    } label: {
                        Text(isExpanded ? "Show less" : "Read more")
                            // 44 pt tall, Apple's smallest comfortable tap target (the text alone is 18)
                            .frame(minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isHighContrast ? Color.primary : DS.Palette.accent)
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            }
            // An old view of the city, if there's a good one (campuses don't have one)
            if !city.isCampus, let old = CityThenPhotos.photo(forCity: city.name), let url = old.url() {
                oldCityPhoto(old, url: url)
            }
        }
        .dsPageMargin()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(city.name) Overview")
        .task(id: city.id) {
            isExpanded = false
            let summary = await WikimediaService.shared.citySummary(for: city.name)
            // A city's article photo is usually its skyline; a university's is often a founder's
            // portrait, a seal or a logo, so campuses use their own landmark photo instead
            // (a city saved for offline use loads its saved photo file instead)
            photoURL = city.isCampus ? nil : OfflineStore.shared.displayURL(for: summary.photoURL)
            if let extract = summary.extract, !extract.isEmpty {
                // Keep only the first two sentences for a tight blurb
                let sentences = extract.components(separatedBy: ". ")
                let blurb = sentences.prefix(2).joined(separator: ". ")
                withAnimation(.easeIn(duration: 0.3)) {
                    cityBlurb = blurb.hasSuffix(".") ? blurb : blurb + "."
                }
            }
        }
    }

    /// The city's own Wikipedia photo, or its first landmark's, with the name on a dark fade.
    private var photoWithTitle: some View {
        ZStack(alignment: .bottomLeading) {
            // The size comes from this clear frame; the photo is laid over it, so a wide
            // photo can't push the whole page wider than the screen
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: photoHeight)
                .overlay {
                    if let photoURL {
                        AsyncImage(url: photoURL) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                landmarkFallback
                            }
                        }
                    } else {
                        landmarkFallback
                    }
                }
                .clipped()
                .accessibilityHidden(true)

            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text(city.details.nickname)
                    .font(.footnote.weight(.bold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.85))
                    // A second line at the largest text sizes: on one line it was still cut off
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(city.name)
                    .font(.system(.largeTitle, design: .serif).bold())
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(DS.Space.l)
        }
        .frame(height: photoHeight)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous)
                .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
        )
    }

    /// The old city view: one wide photo with its caption, credit and source link
    private func oldCityPhoto(_ old: CityThenPhotos.Photo, url: URL) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    DS.Palette.cardBackground.aspectRatio(16 / 9, contentMode: .fit)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .accessibilityLabel(Text(verbatim: old.caption))
            Text(verbatim: old.caption)
                .font(.footnote)
                .foregroundStyle(isHighContrast ? Color.primary : Color.secondary)
            // The credit opens the photo's source page
            Link(destination: old.link) {
                Text(verbatim: old.credit).font(.caption2)
            }
            .foregroundStyle(isHighContrast ? Color.primary : Color.secondary)
        }
    }

    @ViewBuilder
    private var landmarkFallback: some View {
        if let first = city.buildings.first {
            WikiBuildingPhoto(building: first, height: photoHeight)
        } else {
            DS.Palette.cardBackground
        }
    }

    /// Progress ring, rank and (for campuses) conference, in one scannable row
    /// (stacked at accessibility text sizes so words don't break).
    private var facts: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    HStack {
                        progressRing
                        Spacer(minLength: DS.Space.s)
                        conferenceChip
                    }
                    rankText
                }
            } else {
                HStack(spacing: DS.Space.m) {
                    progressRing
                    rankText
                    Spacer(minLength: 0)
                    conferenceChip
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Exploration Progress")
        .accessibilityValue("\(Int(progress * 100)) percent complete. Mastery level: \(masteryTier)")
    }

    private var progressRing: some View {
        ZStack {
            Circle().stroke(accent.opacity(0.18), lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))%")
                .font(.caption2.monospacedDigit().bold())
                .minimumScaleFactor(0.6)
        }
        .frame(width: ringSize, height: ringSize)
    }

    private var rankText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(masteryTier.capitalized)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(String(format: NSLocalizedString("%d of %d landmarks stamped", comment: "City page: progress under the photo"),
                        Int((progress * Double(city.buildings.count)).rounded()), city.buildings.count))
                .font(.footnote)
                .foregroundStyle(isHighContrast ? Color.primary : Color.secondary)
        }
    }

    @ViewBuilder
    private var conferenceChip: some View {
        if let conference = city.conference, conference != .other {
            DSChip(text: conference.name, tint: isHighContrast ? .primary : accent)
        }
    }
}
