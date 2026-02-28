//
//  SwiftUIView.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI

// MARK: - PassportStampView Extensions
extension PassportStampView {
    var sealHeader: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: iconSize))
            .foregroundColor(stampColor)
            .shadow(color: isHighContrast ? .clear : stampColor.opacity(0.3), radius: 5)
            .accessibilityHidden(true)
    }
    
    var cityInfoSection: some View {
        VStack(spacing: 4) {
            Text("PASSPORT STAMPED")
                .font(.caption2.weight(.black))
                .tracking(2)
                .foregroundColor(stampColor)
            
            Text(cityName.uppercased())
                .font(.system(.title2, design: .serif))
                .bold()
            
            if !dateCompleted.isEmpty {
                Text("COMPLETED: \(dateCompleted)")
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundColor(isHighContrast ? .primary : .secondary)
            }
        }
    }
    
    var funFactSection: some View {
        VStack(spacing: 8) {
            Text("DID YOU KNOW?")
                .font(.caption.weight(.heavy))
                .tracking(1)
                .foregroundColor(stampColor)
            
            Text(funFact)
                .font(.system(.footnote, design: .serif))
                .italic()
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    func handleAppearance() {
        if reduceMotion {
            internalOpacity = 1.0
            internalScale = 1.0
        } else {
            internalScale = 1.5
            withAnimation(.interpolatingSpring(stiffness: 120, damping: 10)) {
                internalScale = 1.0
                internalOpacity = 1.0
            }
        }
    }
}

// MARK: - Main Celebration View
struct StampCelebrationView: View {
    let cityName: String
    let date: String
    let funFact: String
    
    @AppStorage("haptics_enabled") var hapticsEnabled = true
    @AppStorage("is_sound_enabled") var soundEnabled = true
    @AppStorage("high_contrast_mode") var highContrast = false
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var systemContrast
    
    @State private var showButton = false
    
    private var isHighContrast: Bool { highContrast || systemContrast == .increased }

    var body: some View {
        ZStack {
            backgroundOverlay
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 40) {
                    VStack(spacing: 8) {
                        Text("City Explored!")
                            .font(.system(.largeTitle, design: .serif))
                            .bold()
                            .foregroundColor(.white)
                        
                        Text(cityName.uppercased())
                            .font(.system(.subheadline, design: .monospaced))
                            .tracking(4)
                            .foregroundColor(isHighContrast ? .white : .white.opacity(0.8))
                    }
                    .padding(.top, 60)
                    .multilineTextAlignment(.center)
                    
                    PassportStampView(
                        cityName: cityName,
                        dateCompleted: date,
                        funFact: funFact,
                        isHighContrast: isHighContrast
                    )
                    .padding(.horizontal)
                    .shadow(color: isHighContrast ? .clear : .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    if showButton {
                        actionButton
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            triggerCelebrationEffects()
        }
    }
}

// MARK: - View Components
extension StampCelebrationView {
    var backgroundOverlay: some View {
        Group {
            if isHighContrast {
                Color.black
            } else {
                Color.black.opacity(0.85)
                    .background(.ultraThinMaterial)
            }
        }
        .ignoresSafeArea()
    }
    
    var actionButton: some View {
        Button(action: {
            if hapticsEnabled { HapticManager.shared.trigger(.selection) }
            dismiss()
        }) {
            Text("Add to Passport")
                .font(Font.headline)
                .foregroundColor(isHighContrast ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isHighContrast ? Color.white : Color.adventureOrange)
                .cornerRadius(14)
        }
        .padding(.horizontal, 40)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
    }
    
    func triggerCelebrationEffects() {
        if hapticsEnabled {
            HapticManager.shared.trigger(.success)
        }

        if soundEnabled {
            SoundManager.shared.playStampSound()
        }

        UIAccessibility.post(notification: .screenChanged, argument: "Congratulations! You've explored \(cityName).")
        
        let delay = reduceMotion ? 0.2 : 1.0
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                showButton = true
            }
        }
    }
}
