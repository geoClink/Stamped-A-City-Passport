//
//  AudioStoryPlayer.swift
//  Stamped! A City Passport
//
//  "Listen" on a landmark page: the landmark's story read aloud by the device's own voice,
//  for standing in front of it with the phone in a pocket. The story is the landmark's facts
//  (when it was built, by whom, in what style) and its description. Landmark descriptions are
//  in English, so the narration uses the best English voice on the device.
//
//  Every story is also recorded ahead of time with the Kokoro voice (tools/landmark-audio).
//  The recordings are Apple-hosted asset packs, LandmarkAudio00–39, each holding the cities
//  whose names hash to it. Opening a landmark downloads its city's pack; until it's there,
//  or offline, the device voice reads the story as before. A clip's file name carries a hash
//  of the text it was recorded from, so after a description changes, the old clip is never
//  found and the device voice reads the new text.
//

import AVFoundation
import BackgroundAssets
import Combine
import CryptoKit
import SwiftUI
import System

@MainActor
final class AudioStoryPlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    static let shared = AudioStoryPlayer()

    /// The landmark being read, or nil when nothing is playing
    @Published private(set) var playingBuildingID: String?

    private let synthesizer = AVSpeechSynthesizer()
    /// Plays a recorded story; nil while the device voice is reading or nothing plays
    private var clipPlayer: AVAudioPlayer?

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    func isPlaying(_ building: Building) -> Bool { playingBuildingID == building.id }

    /// Reads the landmark's story, or stops it if it's already playing.
    func toggle(_ building: Building) {
        if isPlaying(building) {
            stop()
        } else {
            play(building)
        }
    }

    func play(_ building: Building) {
        stop()
        #if os(iOS) || os(visionOS)
        // Spoken audio: plays with the ring switch off, and other audio dips while it talks
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        if let url = recordedClip(for: building), let clip = try? AVAudioPlayer(contentsOf: url) {
            clip.delegate = self
            clipPlayer = clip
            playingBuildingID = building.id
            if clip.play() { return }
            clipPlayer = nil
        }
        prepare(for: building)   // so the recording is there next time
        let utterance = AVSpeechUtterance(string: Self.story(for: building))
        utterance.voice = Self.bestEnglishVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95   // a touch slower, like a guide
        playingBuildingID = building.id
        synthesizer.speak(utterance)
    }

    /// Reads the story and returns when it ends or is stopped, for a guided tour that moves
    /// on to the next landmark when the story is over.
    func playAndWait(_ building: Building) async {
        play(building)
        await withCheckedContinuation { continuation in
            finishWaiter = continuation
        }
    }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        clipPlayer?.stop()
        clipPlayer = nil
        finished()
    }

    /// The tour waiting for the current story to end (playAndWait)
    private var finishWaiter: CheckedContinuation<Void, Never>?

    private func finished() {
        finishWaiter?.resume()
        finishWaiter = nil
        playingBuildingID = nil
        #if os(iOS) || os(visionOS)
        // Let music or a podcast the person paused come back
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
    }

    /// "Willis Tower. Finished in 1974, designed by Bruce Graham (SOM), in the International style.
    /// <description>" — leaving out any fact the app doesn't know.
    nonisolated static func story(for building: Building) -> String {
        var facts: [String] = []
        if building.hasKnownYear { facts.append("Finished in \(building.yearBuilt)") }
        if let architect = building.knownArchitect { facts.append("designed by \(architect)") }
        if let style = building.knownStyle { facts.append("in the \(style) style") }
        let factsSentence = facts.isEmpty ? "" : " " + facts.joined(separator: ", ") + "."
        return "\(building.name).\(factsSentence) \(building.description)"
    }

    /// The most natural English voice on the device: Premium, then Enhanced, then the basic
    /// (Compact) one every device has. Within the same quality, the person's own English
    /// (en-GB, en-AU…) wins over en-US. Better voices are free downloads in Settings.
    private static func bestEnglishVoice() -> AVSpeechSynthesisVoice? {
        let english = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        let preferred = Locale.current.language.languageCode?.identifier == "en" ? Locale.current.identifier.replacingOccurrences(of: "_", with: "-") : "en-US"
        // Novelty voices (Bells, Bubbles…) and Personal Voice are left out
        let natural = english.filter { !$0.voiceTraits.contains(.isNoveltyVoice) && !$0.voiceTraits.contains(.isPersonalVoice) }
        let best = natural.max { first, second in
            if first.quality != second.quality { return rank(first.quality) < rank(second.quality) }
            return first.language != preferred && second.language == preferred
        }
        return best
            ?? AVSpeechSynthesisVoice(language: preferred)
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    /// True when only the basic, robotic-sounding English voice is installed, so the Listen
    /// button can suggest downloading a better one
    static var hasOnlyBasicVoice: Bool {
        guard let voice = bestEnglishVoice() else { return true }
        return voice.quality == .default
    }

    private static func rank(_ quality: AVSpeechSynthesisVoiceQuality) -> Int {
        switch quality {
        case .premium: return 2
        case .enhanced: return 1
        default: return 0
        }
    }

    // MARK: - Recorded stories

    /// Number of LandmarkAudio packs. Must match PACKS in tools/landmark-audio/package.py;
    /// changing it moves cities between packs, so leave it alone once packs are uploaded.
    private static let packCount: UInt32 = 40

    /// The pack holding a city's stories: "LandmarkAudio07". Same rule as package.py.
    nonisolated static func packID(forCity cityName: String) -> String {
        let bytes = Array(SHA256.hash(data: Data(cityName.utf8)))
        let number = (UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])) % packCount
        return String(format: "LandmarkAudio%02d", number)
    }

    /// The clip's path inside its pack: the landmark ID and the first 8 hex digits of the
    /// story text's SHA-256, so a clip recorded from older text doesn't match.
    nonisolated static func clipPath(for building: Building) -> String {
        let hash = SHA256.hash(data: Data(story(for: building).utf8)).map { String(format: "%02x", $0) }.joined()
        return "LandmarkAudio/\(building.id)-\(hash.prefix(8)).m4a"
    }

    /// Which city each landmark belongs to, by landmark ID
    private lazy var cityByBuildingID: [String: String] = {
        var map: [String: String] = [:]
        for (city, buildings) in BuildingRegistry.data {
            for building in buildings where map[building.id] == nil { map[building.id] = city.rawValue }
        }
        return map
    }()

    /// The downloaded recording of this landmark's story, if its pack is on the device
    private func recordedClip(for building: Building) -> URL? {
        // Older systems (the iPhone app still runs on iOS 18) keep the device voice
        guard #available(iOS 26.4, macOS 26.4, visionOS 26.4, *) else { return nil }
        guard let city = cityByBuildingID[building.id],
              AssetPackManager.shared.assetPackIsAvailableLocally(withID: Self.packID(forCity: city)),
              let url = try? AssetPackManager.shared.url(for: FilePath(Self.clipPath(for: building))),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    /// True when this landmark's story will play as a recording rather than the device voice
    func hasRecording(_ building: Building) -> Bool { recordedClip(for: building) != nil }

    /// Packs already asked for in this session, so each one is requested once
    private var requestedPacks: Set<String> = []

    /// Starts downloading the pack with this landmark's city, if it isn't on the device yet.
    /// Called when a landmark page opens; a failure (offline, pack not released yet) just
    /// leaves the device voice in place.
    func prepare(for building: Building) {
        guard #available(iOS 26.4, macOS 26.4, visionOS 26.4, *) else { return }
        guard let city = cityByBuildingID[building.id] else { return }
        let packID = Self.packID(forCity: city)
        guard !requestedPacks.contains(packID),
              !AssetPackManager.shared.assetPackIsAvailableLocally(withID: packID) else { return }
        requestedPacks.insert(packID)
        Task {
            do {
                let pack = try await AssetPackManager.shared.assetPack(withID: packID)
                try await AssetPackManager.shared.ensureLocalAvailability(of: pack)
            } catch {
                requestedPacks.remove(packID)   // try again next time
            }
        }
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard player === self.clipPlayer else { return }
            self.clipPlayer = nil
            self.finished()
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finished() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finished() }
    }
}
