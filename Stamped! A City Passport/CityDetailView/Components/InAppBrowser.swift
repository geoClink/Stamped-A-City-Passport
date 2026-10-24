//
//  InAppBrowser.swift
//  Stamped! A City Passport
//
//  Shows a web page (restaurant site, ticket page…) in a sheet without leaving the app.
//  Safari's own view: it shares the user's Safari logins and has a Done button built in.
//

import SwiftUI
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

/// Lets `.sheet(item:)` present a URL (sheets need an Identifiable item).
struct BrowserLink: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
