//
//  ListenButton.swift
//  Stamped! A City Passport
//
//  The "Listen" / "Stop" button on a landmark page (iPhone, iPad and Mac). The player itself,
//  AudioStoryPlayer, is shared with the Vision Pro app; this button uses the iPhone design system.
//

import SwiftUI

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
