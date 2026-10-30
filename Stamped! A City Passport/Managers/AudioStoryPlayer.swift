//
//  AudioStoryPlayer.swift
//  Stamped! A City Passport
//
//  "Listen" on a landmark page: the landmark's story read aloud by the device's own voice,
//  for standing in front of it with the phone in a pocket. The story is the landmark's facts
//  (when it was built, by whom, in what style) and its description. Landmark descriptions are
//  in English, so the narration uses the best English voice on the device.
//

import AVFoundation
import Combine
import SwiftUI

@MainActor
final class AudioStoryPlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = AudioStoryPlayer()

    /// The landmark being read, or nil when nothing is playing
    @Published private(set) var playingBuildingID: String?

    private let synthesizer = AVSpeechSynthesizer()

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
        let utterance = AVSpeechUtterance(string: Self.story(for: building))
        utterance.voice = Self.bestEnglishVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95   // a touch slower, like a guide
        playingBuildingID = building.id
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        finished()
    }

    private func finished() {
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

    /// An enhanced (higher quality) English voice if one is installed, else the standard one
    private static func bestEnglishVoice() -> AVSpeechSynthesisVoice? {
        let english = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        let preferred = Locale.current.language.languageCode?.identifier == "en" ? Locale.current.identifier.replacingOccurrences(of: "_", with: "-") : "en-US"
        return english.first { $0.language == preferred && $0.quality != .default }
            ?? english.first { $0.quality != .default }
            ?? AVSpeechSynthesisVoice(language: preferred)
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finished() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finished() }
    }
}

/// The "Listen" / "Stop" button above a landmark's story
struct ListenButton: View {
    let building: Building
    let tint: Color
    @ObservedObject private var player = AudioStoryPlayer.shared

    var body: some View {
        let playing = player.isPlaying(building)
        Button {
            HapticManager.shared.trigger(.selection)
            player.toggle(building)
        } label: {
            Label(playing ? NSLocalizedString("Stop", comment: "Audio story: stops reading the landmark's story aloud")
                          : NSLocalizedString("Listen", comment: "Audio story: reads the landmark's story aloud"),
                  systemImage: playing ? "stop.fill" : "speaker.wave.2.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(tint)
                .padding(.horizontal, DS.Space.m)
                .padding(.vertical, DS.Space.s)
                .background(Capsule().fill(tint.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .accessibilityHint(playing ? "" : NSLocalizedString("Reads this landmark's story aloud in English", comment: "Audio story: VoiceOver hint for Listen"))
    }
}
