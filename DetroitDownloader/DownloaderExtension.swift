//
//  DownloaderExtension.swift
//  DetroitDownloader
//
//  A tiny app extension that Background Assets needs before it will download
//  Apple-hosted asset packs (the Detroit 3D model). The system runs it in the
//  background, even while the app is closed. StoreKit does all the work;
//  there's nothing to add here.
//

import BackgroundAssets
import ExtensionFoundation
import StoreKit

@main
struct DownloaderExtension: StoreDownloaderExtension {
    func shouldDownload(_ assetPack: AssetPack) -> Bool {
        // Download every pack the app asks for. The only one is "Detroit3D",
        // and it's on-demand, so it only downloads when the user taps Download.
        return true
    }
}
