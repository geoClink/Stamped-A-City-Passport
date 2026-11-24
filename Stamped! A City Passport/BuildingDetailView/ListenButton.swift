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
    /// Set once the person taps Listen with only the basic voice installed
    @State private var showVoiceTip = false
    /// "Got it" hides the voice tip for good
    @AppStorage("listenVoiceTipDismissed") private var voiceTipDismissed = false

    var body: some View {
        let playing = player.isPlaying(building)
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Button {
                HapticManager.shared.trigger(.selection)
                player.toggle(building)
                if !voiceTipDismissed && !player.hasRecording(building) && AudioStoryPlayer.hasOnlyBasicVoice {
                    showVoiceTip = true
                }
            } label: {
                Label(playing ? NSLocalizedString("Stop", comment: "Audio story: stops reading the landmark's story aloud")
                              : NSLocalizedString("Listen", comment: "Audio story: reads the landmark's story aloud"),
                      systemImage: playing ? "stop.fill" : "speaker.wave.2.fill")
            }
            .buttonStyle(DSPillButtonStyle(tint: tint))
            .accessibilityHint(playing ? "" : NSLocalizedString("Reads this landmark's story aloud in English", comment: "Audio story: VoiceOver hint for Listen"))

            if showVoiceTip && !voiceTipDismissed {
                VoiceTip(tint: tint) { voiceTipDismissed = true }
            }
        }
        // Fetch the recording of this city's stories while the person reads the page
        .task(id: building.id) { player.prepare(for: building) }
    }
}

/// "For a more natural voice…": where to download a better English voice in Settings
private struct VoiceTip: View {
    let tint: Color
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DS.Space.s) {
            Image(systemName: "waveform")
                .foregroundColor(tint)
                .accessibilityHidden(true)
            Text(Self.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(NSLocalizedString("Got it", comment: "Audio story: hides the tip about downloading a better voice")) {
                onDismiss()
            }
            .font(.footnote.weight(.semibold))
            .foregroundColor(tint)
            .buttonStyle(.plain)
        }
    }

    // The Settings path is different on the Mac
    private static var message: String {
        #if os(macOS)
        NSLocalizedString("For a more natural voice, download a Premium English voice in System Settings > Accessibility > Spoken Content > System Voice > Manage Voices.", comment: "Audio story: tip on Mac when only the basic voice is installed")
        #else
        NSLocalizedString("For a more natural voice, download a Premium English voice in Settings > Accessibility > Read & Speak > Voices.", comment: "Audio story: tip on iPhone and iPad when only the basic voice is installed")
        #endif
    }
}
