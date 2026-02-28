//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI
import AVFoundation
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    
    // MARK: - Persisted Settings
    @AppStorage("reduce_motion") var reduceMotion = false
    @AppStorage("high_contrast_mode") var highContrast = false
    @AppStorage("haptics_enabled") var hapticsEnabled = true
    @AppStorage("is_sound_enabled") var isSoundEnabled = true
    @AppStorage("use_metric_units") var useMetric = true
    
    // MARK: - Computed Properties
    var brandColor: Color {
        highContrast ? .primary : Color.adventureOrange
    }
    
    // MARK: - Audio & Haptics Logic
    func playSoundPreview() {
        guard isSoundEnabled else { return }
        let systemSoundID: UInt32 = 1322
        AudioServicesPlaySystemSound(systemSoundID)
    }
    
   
    
    // MARK: - Data Management
    func resetAllContent() {
        HapticManager.shared.trigger(HapticStyle.success)
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
        
        GlobalProgressManager.shared.resetAllProgress()
        
        reduceMotion = false
        highContrast = false
        useMetric = true
        hapticsEnabled = true
        isSoundEnabled = true
    }
}
