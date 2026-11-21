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
        #if os(visionOS)
        /// On visionOS cards sit on window glass: a light lift reads as a platter, where the
        /// grouped gray drew opaque dark boxes
        static let cardBackground = Color.white.opacity(0.08)
        #else
        static let cardBackground = Color(UIColor.secondarySystemGroupedBackground)
        #endif
        static let pageBackground = Color(UIColor.systemGroupedBackground)
        /// Boxes inside a card (a timeline tile, a stat cell): a faint tint, never a second card color
        static let insetFill = Color.primary.opacity(0.05)
    }

    /// Five text roles beyond the system styles. Screens use these instead of picking sizes.
    /// All scale with Dynamic Type.
    enum Typography {
        /// City and landmark names, passport headings: the serif display face
        static func display(_ style: Font.TextStyle = .title) -> Font {
            .system(style, design: .serif).weight(.bold)
        }
        /// Card titles
        static let cardTitle = Font.headline
        /// Tracked uppercase labels (section headers, eyebrow tags). Use with `.tracking(1.2)`.
        static let label = Font.footnote.weight(.bold)
        /// Numbers, dates, progress, dossier metadata: the only monospaced role
        static let data = Font.caption.monospaced().weight(.bold)
        /// Source notes and fine print under a section
        static let fineprint = Font.caption2
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
        #if os(visionOS)
        // visionOS has no scroll edge effects; windows draw their own glass
        content
        #else
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
        #endif
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
                    // Decorative: the title says it; otherwise VoiceOver reads the symbol's name first
                    .accessibilityHidden(true)
            }
            Text(title)
                .tracking(1.2)
                .foregroundStyle(isHighContrast ? Color.primary : Color.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: DS.Space.s)
            trailing()
        }
        .font(DS.Typography.label)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: DS.Space.xs) {
            if let systemImage { Image(systemName: systemImage).accessibilityHidden(true) }
            // One line normally; wraps at accessibility sizes instead of cutting off ("Italian Renai…")
            Text(text)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, DS.Space.m)
        .padding(.vertical, 6)
        .foregroundStyle(tint)
        .background(Capsule().fill(tint.opacity(0.12)))
    }
}

// MARK: - Buttons

/// The one filled button a screen gets: Stamp, Start Quiz, Save for Offline.
struct DSPrimaryButtonStyle: ButtonStyle {
    var tint: Color = DS.Palette.accent
    var isHighContrast = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .multilineTextAlignment(.center)
            .padding(.vertical, DS.Space.l)
            .padding(.horizontal, DS.Space.m)
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(isHighContrast ? Color.primary : Color.white)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(isHighContrast ? Color.clear : tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// A compact action in a row of two to four under the primary button: icon over a short label
/// on the card surface. Only the icon carries the tint, so a row of them reads as one group.
struct DSActionTileStyle: ButtonStyle {
    var tint: Color = DS.Palette.accent
    var isHighContrast = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(DSTileLabelStyle(tint: isHighContrast ? .primary : tint))
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.vertical, DS.Space.m)
            .padding(.horizontal, DS.Space.xs)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(isHighContrast ? Color.clear : DS.Palette.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct DSTileLabelStyle: LabelStyle {
    let tint: Color
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: DS.Space.xs) {
            configuration.icon
                .font(.title3)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            configuration.title
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
        }
    }
}

/// A small tinted capsule for in-line extras next to content: Listen, Ask, Step into the Past.
struct DSPillButtonStyle: ButtonStyle {
    var tint: Color = DS.Palette.accent
    var isHighContrast = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isHighContrast ? Color.primary : tint)
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, DS.Space.s)
            .frame(minHeight: 36)
            .background(Capsule().fill(isHighContrast ? Color.clear : tint.opacity(0.12)))
            .overlay(Capsule().stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Link row

/// One row of a links card: tours, restaurants, hotels, the address. Every outbound link in
/// the app uses this, stacked inside a `dsCard(padding: 0)` with `DSRowDivider`s between rows.
struct DSLinkRow: View {
    let title: Text
    var subtitle: Text? = nil
    let systemImage: String
    /// arrow.up.right for another app or site, chevron.right for a page in Stamped
    var trailingSymbol = "arrow.up.right"
    var isHighContrast = false

    var body: some View {
        HStack(spacing: DS.Space.m) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(isHighContrast ? Color.primary : DS.Palette.accent)
                .frame(minWidth: 28)  // grows with the icon at large text sizes, so it never overlaps the title
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if let subtitle {
                    subtitle
                        .font(.caption)
                        .foregroundStyle(isHighContrast ? Color.primary : Color.secondary)
                }
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: DS.Space.s)
            Image(systemName: trailingSymbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isHighContrast ? Color.primary : Color.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, DS.Space.l)
        .padding(.vertical, DS.Space.m)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// Every outbound link (tours, tables, hotels, rentals) as one look: a single-row card with the
/// icon in brand orange and an arrow showing it leaves the page. Put it on the link's Label, or
/// on a container to style the Labels of link buttons inside it.
struct DSLinkLabelStyle: LabelStyle {
    var isHighContrast = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: DS.Space.m) {
            configuration.icon
                .font(.body.weight(.semibold))
                .foregroundStyle(isHighContrast ? Color.primary : DS.Palette.accent)
                .frame(minWidth: 28)  // grows with the icon at large text sizes, so it never overlaps the title
                .accessibilityHidden(true)
            configuration.title
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: DS.Space.s)
            Image(systemName: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isHighContrast ? Color.primary : Color.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, DS.Space.l)
        .padding(.vertical, DS.Space.m)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(isHighContrast ? Color.clear : DS.Palette.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
    }
}

/// The hairline between rows in a links card, inset to line up with the row titles.
struct DSRowDivider: View {
    var body: some View {
        Divider().padding(.leading, DS.Space.l + 28 + DS.Space.m)
    }
}

// MARK: - Placeholder

/// What shows where a photo hasn't loaded or doesn't exist: the brand tint and one symbol.
/// Used for landmark thumbnails, rail cards and hero images so missing pictures look alike.
struct DSPlaceholder: View {
    var systemImage = "building.columns"
    var isHighContrast = false
    var cornerRadius: CGFloat = DS.Radius.small

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(isHighContrast ? Color.primary.opacity(0.08) : DS.Palette.accent.opacity(0.12))
            .overlay {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isHighContrast ? Color.primary : DS.Palette.accent.opacity(0.8))
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Loading row

/// The one "still fetching" line: a small spinner and a short caption, e.g. "Finding nearby spots…".
struct DSLoadingRow: View {
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: DS.Space.s) {
            ProgressView().controlSize(.small)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Rail card

/// A card in a sideways-scrolling row (Local Flavors, Stays Near Here): fixed width that grows
/// with text size, the card surface, content pinned to the top.
struct DSRailCard: ViewModifier {
    let width: CGFloat
    var isHighContrast = false

    func body(content: Content) -> some View {
        content
            .padding(DS.Space.m)
            .frame(width: width, alignment: .leading)
            .frame(minHeight: width, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(isHighContrast ? Color.clear : DS.Palette.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(Color.primary, lineWidth: isHighContrast ? 2 : 0)
            )
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
    }
}

extension View {
    func dsRailCard(width: CGFloat, isHighContrast: Bool = false) -> some View {
        modifier(DSRailCard(width: width, isHighContrast: isHighContrast))
    }

    /// The standard title for a screen shown in a sheet: inline, so every sheet's header lines up
    /// with its Done button. Top-level pages pushed in a stack keep their own large titles.
    func dsSheetTitle(_ title: LocalizedStringKey) -> some View {
        #if os(iOS)
        navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        #else
        navigationTitle(title)
        #endif
    }
}

// MARK: - Shimmer Effect

extension View {
    func shimmering() -> some View { self.modifier(ShimmerModifier()) }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            // Closure form: LinearGradient is both a View and a ShapeStyle, and
            // both have .blendMode, so .overlay(...) can't tell which is meant.
            // The @ViewBuilder closure only accepts Views, which settles it.
            .overlay {
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .white.opacity(0.4), .clear]),
                    startPoint: .init(x: phase - 0.3, y: 0),
                    endPoint: .init(x: phase, y: 0)
                )
                .blendMode(.screen)
            }
            .onAppear {
                // With Reduce Motion the placeholder stays still instead of sweeping forever
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { phase = 1.3 }
            }
    }
}
