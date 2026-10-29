//
//  InAppBrowser.swift
//  Stamped! A City Passport
//
//  Shows a web page (restaurant site, ticket page…) in a sheet without leaving the app.
//  Safari's own view: it shares the user's Safari logins and has a Done button built in.
//  On the Mac there is no Safari view, so links open in the user's default browser.
//

import SwiftUI
#if os(iOS)
import SafariServices

struct InAppBrowser: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(named: "adventureOrange")
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
#endif

extension View {
    /// Shows `item`'s page in Safari's sheet on iPhone/iPad, or in the default browser on the Mac.
    func inAppBrowser(item: Binding<BrowserLink?>) -> some View {
        #if os(iOS)
        sheet(item: item) { link in
            InAppBrowser(url: link.url).ignoresSafeArea()
        }
        #else
        modifier(ExternalBrowserOpener(item: item))
        #endif
    }
}

#if !os(iOS)
private struct ExternalBrowserOpener: ViewModifier {
    @Binding var item: BrowserLink?
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content.onChange(of: item?.id) {
            guard let link = item else { return }
            openURL(link.url)
            item = nil
        }
    }
}
#endif

/// Lets `.sheet(item:)` present a URL (sheets need an Identifiable item).
struct BrowserLink: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
