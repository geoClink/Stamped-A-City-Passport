import SwiftUI

// MARK: - Share Button

/// Shares a city (or campus) stamp as a picture plus a message with the App Store link.
/// Each screen passes its own look for the button.
struct CityStampShareButton<ButtonLabel: View>: View {
    let city: CityLocation.City
    @ViewBuilder let label: () -> ButtonLabel

    /// The stamp drawn as a picture; nil until it's rendered
    @State private var shareImage: Image?

    /// Sent with the picture (in Messages, Mail and most apps), so friends can tap straight to the app
    private var shareMessage: String {
        String(format: NSLocalizedString("I just unlocked the %1$@ stamp on Stamped! 🏛️ Get the app: %2$@",
                                         comment: "Text sent with a shared city stamp picture; %1$@ is the city, %2$@ is the App Store link"),
               city.name, ShareCardLink.appStore(campaign: "city-share"))
    }

    var body: some View {
        Group {
            if let image = shareImage {
                ShareLink(item: image, message: Text(shareMessage), preview: SharePreview(city.name, image: image)) {
                    label()
                }
            } else {
                // Text and link only, for the moment before the picture is ready
                ShareLink(item: shareMessage) { label() }
            }
        }
        .task { renderShareImage() }
    }

    @MainActor
    private func renderShareImage() {
        let visitedIDs = GlobalProgressManager.shared.visitedIDs
        let stampedCount = city.buildings.filter { visitedIDs.contains($0.id) }.count
        let date = UserDefaults.standard.string(forKey: "date_completed_\(city.name)") ?? ""
        shareImage = ShareCardRenderer.image(of: CityStampShareCard(city: city, stampedCount: stampedCount, date: date))
    }
}
