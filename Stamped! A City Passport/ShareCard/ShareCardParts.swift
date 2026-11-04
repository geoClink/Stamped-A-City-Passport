import SwiftUI

// MARK: - Pieces shared by the passport and city stamp share cards

enum ShareCardLink {
    /// The App Store link that goes with a shared picture. pt is our App Store Connect provider
    /// token and ct the campaign, so App Analytics → Campaigns counts downloads from each kind of share.
    static func appStore(campaign: String) -> String {
        "https://apps.apple.com/app/apple-store/id6759680336?pt=128288066&ct=\(campaign)&mt=8"
    }
}

enum ShareCardRenderer {
    /// Draws a share card into a picture at the screen's pixel density
    @MainActor
    static func image(of card: some View) -> Image? {
        let renderer = ImageRenderer(content: card)
        #if os(visionOS)
        renderer.scale = 2.0
        #elseif os(macOS)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        #else
        renderer.scale = UIScreen.main.scale
        #endif
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}

/// "STAMPED! A CITY PASSPORT" with this month's date, white on the orange band
struct ShareCardBrandBar: View {
    var body: some View {
        HStack {
            HStack(spacing: DS.Space.s) {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 0) {
                    Text("STAMPED!")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.black)
                        .foregroundStyle(.white)
                    Text("A CITY PASSPORT")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .tracking(2)
                }
            }
            Spacer()
            Text(Date().formatted(.dateTime.month(.abbreviated).year()))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, DS.Space.xl)
        .padding(.top, DS.Space.xl)
        .padding(.bottom, DS.Space.l)
    }
}

/// Small "ON THE APP STORE" line at the bottom of a card
struct ShareCardFooter: View {
    var body: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .font(.caption2)
                .foregroundStyle(DS.Palette.accent.opacity(0.4))
            // Not a web address: stamped-app.com belongs to someone else
            Text("ON THE APP STORE")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(DS.Palette.accent.opacity(0.4))
                .tracking(1)
        }
        .padding(.horizontal, DS.Space.l)
        .padding(.bottom, DS.Space.l)
    }
}
