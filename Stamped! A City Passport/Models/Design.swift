//
//  Design.swift
//  Stamped! A City Passport
//
//  The app's design system in code: one spacing scale, three corner radii, the
//  colors and the shared pieces (card, section header, stat chip) every screen
//  builds from. DESIGN_STYLE_GUIDE.md explains the reasoning; this file is the
//  source of truth for the numbers, so screens don't each pick their own.
//

import SwiftUI

enum DS {
    /// A 4-point spacing scale. Page edges use `page`, gaps between sections `section`.
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let section: CGFloat = 32
        /// Left and right edge of every screen's content
        static let page: CGFloat = 16
    }

    /// Three corner radii: chips and small controls, cards, and large hero surfaces.
    enum Radius {
        static let small: CGFloat = 10
        static let card: CGFloat = 16
        static let large: CGFloat = 24
    }

    /// Colors with a single job each (see "Color Rules" in the style guide).
    enum Palette {
        /// Actions, progress, stamps
        static let accent = Color.adventureOrange
        /// Want to Visit only
        static let wishlist = Color.pink
        /// Mastery and full completion only
        static let gold = Color(red: 0.85, green: 0.65, blue: 0.13)
        static let cardBackground = Color(UIColor.secondarySystemGroupedBackground)
        static let pageBackground = Color(UIColor.systemGroupedBackground)
    }
}

// MARK: - Card

/// The one card style: grouped background, card radius, no shadow by default.
/// In high contrast it gets a solid border instead of relying on the background.
struct DSCard: ViewModifier {
    var padding: CGFloat = DS.Space.l
    var isHighContrast = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(isHighContrast ? Color(UIColor.systemBackground) : DS.Palette.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
            )
    }
}

extension View {
    /// Wraps the view in the app's standard card.
    func dsCard(padding: CGFloat = DS.Space.l, isHighContrast: Bool = false) -> some View {
        modifier(DSCard(padding: padding, isHighContrast: isHighContrast))
    }

    /// The standard left/right page margin.
    func dsPageMargin() -> some View {
        padding(.horizontal, DS.Space.page)
    }

    /// A solid bar behind the status bar and the top buttons once the page scrolls under them.
    /// Put it on the page's ScrollView.
    func dsSolidTopScrollEdge() -> some View {
        modifier(DSSolidTopScrollEdge())
    }

    /// A big sheet on iPad, for a sheet that holds a whole page, a map or a picture.
    /// A plain iPad sheet is a small centered window; `.page` makes it nearly fill the screen.
    /// On iPhone a sheet already fills the screen, so nothing changes there.
    /// Put it on the sheet's content. The Mac and Vision Pro keep their own sheet sizes.
    func dsLargeSheet() -> some View {
        #if os(iOS)
        presentationSizing(.page)
        #else
        self
        #endif
    }
}

/// iOS 26's default "soft" scroll edge only fades content a little, so text stayed readable
/// under the clock and the floating buttons. The "hard" edge draws a solid bar, but it also
/// shows while the page is at rest, so we switch to it only after the page has scrolled.
/// Before iOS 26 the navigation bar already turns solid on scroll, so nothing changes there.
struct DSSolidTopScrollEdge: ViewModifier {
    @State private var isScrolled = false

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    // True once the content has moved up from its resting spot
                    geometry.contentOffset.y + geometry.contentInsets.top > 1
                } action: { _, scrolled in
                    isScrolled = scrolled
                }
                .scrollEdgeEffectStyle(isScrolled ? .hard : .soft, for: .top)
        } else {
            content
        }
    }
}

// MARK: - Section header

/// Every section on a page starts with this: a small tracked label, an optional
/// icon, and optional trailing content (a count, a "See all" link).
struct DSSectionHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    var systemImage: String? = nil
    var isHighContrast = false
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(isHighContrast ? Color.primary : DS.Palette.accent)
            }
            Text(title)
                .tracking(1.2)
                .foregroundStyle(isHighContrast ? Color.primary : Color.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: DS.Space.s)
            trailing()
        }
        .font(.footnote.weight(.bold))
        .textCase(.uppercase)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

extension DSSectionHeader where Trailing == EmptyView {
    init(_ title: LocalizedStringKey, systemImage: String? = nil, isHighContrast: Bool = false) {
        self.title = title
        self.systemImage = systemImage
        self.isHighContrast = isHighContrast
        self.trailing = { EmptyView() }
    }
}

// MARK: - Stat chip

/// A small capsule for facts and states: "Built 1856", "Big Ten", "Collegiate Gothic".
struct DSChip: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: DS.Space.xs) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text).lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, DS.Space.m)
        .padding(.vertical, 6)
        .foregroundStyle(tint)
        .background(Capsule().fill(tint.opacity(0.12)))
    }
}
