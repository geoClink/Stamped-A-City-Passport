//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/19/26.
//

import Foundation
import AudioToolbox
import SwiftUI
import AVFoundation
import Combine

@MainActor
class SoundManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = SoundManager()
    
    @Published var isSpeaking: Bool = false
    
    private var audioPlayer: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    
    @AppStorage("is_sound_enabled") private var isSoundEnabled = true
    
    override private init() {
        super.init()
        synthesizer.delegate = self
    }
    
    // MARK: - System Sounds
    enum SystemSound: SystemSoundID {
        case success = 1022
        case cameraShutter = 1108
        case paymentSuccess = 1407
        case tweetSent = 1016
        case landmarkTick = 1054

        case sentMessage = 1004
        case receivedMessage = 1003
        case tweetReceived = 1015
        
        case lock = 1100
        case unlock = 1101
        case tink = 1103
        case tock = 1104
        case shortcutClick = 1105
        
        case calendarAlert = 1005
        case chargingStarted = 1354
        case scanSuccess = 1256
        case negativeFeedback = 1053
        
        case fanfare = 1075
        case tick = 1156
        case lowBattery = 1306
        case activityGoalReached = 1025
    }

    func playLandmarkSound() {
        playSystemSound(.negativeFeedback)
    }
    
    func playSystemSound(_ sound: SystemSound) {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(sound.rawValue)
    }
    
    func playStampSound() {
        playSystemSound(.paymentSuccess)
    }
    
    // MARK: - Speech Synthesis
    func speakGreeting(_ greeting: String, for country: CityLocation.Country) {
        guard isSoundEnabled else { return }
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .spokenAudio, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Audio Session Error: \(error)")
        }
        
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: greeting)
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.0
        
        let langCode: String = switch country {
        case .mexico, .peru, .chile, .argentina: "es-MX"
        case .spain: "es-ES"
        case .france: "fr-FR"
        case .italy: "it-IT"
        case .japan: "ja-JP"
        case .southkorea: "ko-KR"
        case .china: "zh-CN"
        case .sar: "zh-HK"
        case .brazil: "pt-BR"
        case .portugal: "pt-PT"
        case .germany, .austria: "de-DE"
        case .saudiArabia, .uae, .egypt, .morocco: "ar-SA"
        case .thailand: "th-TH"
        case .israel: "he-IL"
        default: "en-US"
        }
        
        let voice = AVSpeechSynthesisVoice.speechVoices().first { v in
            v.language == langCode && v.quality == .enhanced
        } ?? AVSpeechSynthesisVoice(language: langCode)
        
        utterance.voice = voice
        synthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
