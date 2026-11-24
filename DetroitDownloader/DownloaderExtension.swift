//
//  DownloaderExtension.swift
//  DetroitDownloader
//
//  A tiny app extension that Background Assets needs before it will download
//  Apple-hosted asset packs: the Detroit 3D model (Vision Pro) and the recorded landmark
//  stories, LandmarkAudio00–39 (every platform). The system runs it in the
//  background, even while the app is closed. StoreKit does all the work;
//  there's nothing to add here.
//

import BackgroundAssets
import ExtensionFoundation
import StoreKit

@main
struct DownloaderExtension: StoreDownloaderExtension {
    func shouldDownload(_ assetPack: AssetPack) -> Bool {
        // Download every pack the app asks for. They're all on-demand, so nothing
        // downloads until the app asks: Detroit3D when the user taps Download, a
        // LandmarkAudio pack when a city with landmarks in it is opened.
        return true
    }
}
