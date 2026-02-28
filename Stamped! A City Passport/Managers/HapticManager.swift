//
//  HapticStyle.swift
//  Stamped
//
//  Created by George Clinkscales on 2/1/26.
//

import SwiftUI
import UIKit

enum HapticStyle: Sendable {
    case selection, impact, warning, success, error, heavy
}

@MainActor
final class HapticManager {
    static let shared = HapticManager()
    static let settingsKey = "haptics_enabled"
    
    @AppStorage(HapticManager.settingsKey) var hapticsEnabled = true

    private init() {
        UserDefaults.standard.register(defaults: [
            HapticManager.settingsKey: true
        ])
    }
    
    func trigger(_ style: HapticStyle) {
        let isActuallyEnabled = UserDefaults.standard.bool(forKey: HapticManager.settingsKey)
        
        guard isActuallyEnabled else {
            print("DEBUG: Haptic blocked. Settings are OFF.")
            return
        }
        
        switch style {
        case .selection: UISelectionFeedbackGenerator().selectionChanged()
        case .impact: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error: UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
