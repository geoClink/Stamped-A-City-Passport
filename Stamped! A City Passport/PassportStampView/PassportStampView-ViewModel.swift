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
        VStack(spacing: DS.Space.xs) {
            Text("PASSPORT STAMPED")
                .font(.caption2.weight(.black))
                .tracking(2)
                .foregroundColor(stampColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            // Shrinks rather than breaking a long name mid-word
            Text(cityName.uppercased())
                .font(.system(.title2, design: .serif))
                .bold()
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
            
            if !dateCompleted.isEmpty {
                Text("COMPLETED: \(dateCompleted)")
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundColor(isHighContrast ? .primary : .secondary)
            }
        }
    }
    
    var funFactSection: some View {
        VStack(spacing: DS.Space.s) {
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
                VStack(spacing: DS.Space.section) {
                    VStack(spacing: DS.Space.s) {
                        // Campuses get their own wording
                        Text(CityLocation.City(rawValue: cityName)?.isCampus == true ? "Campus Explored!" : "City Explored!")
                            .font(.system(.largeTitle, design: .serif))
                            .bold()
                            .foregroundColor(.white)
                        
                        Text(cityName.uppercased())
                            .font(.system(.subheadline, design: .monospaced))
                            .tracking(4)
                            .foregroundColor(isHighContrast ? .white : .white.opacity(0.8))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.top, DS.Space.section * 2)
                    .multilineTextAlignment(.center)
                    .dsPageMargin()
                    
                    PassportStampView(
                        cityName: cityName,
                        dateCompleted: date,
                        funFact: funFact,
                        isHighContrast: isHighContrast
                    )
                    .dsPageMargin()
                    // Lifts the stamp off the dark backdrop
                    .shadow(color: isHighContrast ? .clear : .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    if showButton {
                        actionButton
                    }
                }
                .padding(.bottom, DS.Space.section)
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
                .padding(.vertical, DS.Space.l)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .fill(isHighContrast ? Color.white : DS.Palette.accent)
                )
        }
        .padding(.horizontal, DS.Space.section)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showButton = true
            }
        }
    }
}
