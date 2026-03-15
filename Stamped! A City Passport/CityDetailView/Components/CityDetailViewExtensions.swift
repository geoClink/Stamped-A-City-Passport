//
//  SwiftUIView.swift
//  Stamped
//
//  Created by George Clinkscales on 2/1/26.
//

import SwiftUI
import PhotosUI

// MARK: - MAIN COMPONENTS
extension CityDetailView {
    
    @ViewBuilder
    var celebrationCover: some View {
        StampCelebrationView(
            cityName: viewModel.city.name,
            date: viewModel.completionDate,
            funFact: viewModel.city.details.funFact
        )
    }
    
    @ViewBuilder
    func travelDisclosure(title: String, value: String, icon: String, info: String, subTitle: String? = nil) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(subTitle ?? "Information")
                        .font(.caption.bold())
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if title == "Language" { languageGreetingButton }
                    if title == "Currency" { currencySwapButton }
                }
                
                if title == "Currency" {
                    currencyConverterStack
                }
                
                Text(info)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if title == "Currency" {
                    Text("Rates updated February 2026. Offline mode.")
                        .font(.system(size: 10, weight: .light))
                        .italic()
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 8)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(isHighContrast ? .primary : .adventureOrange)
                    .font(.subheadline)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(isHighContrast ? .primary : .secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 8)
                
                Text(value)
                    .font(.subheadline.bold())
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .padding()
    }
}
// MARK: - PRIVATE SUB-COMPONENTS
private extension CityDetailView {
    
    var languageGreetingButton: some View {
        Button(action: {
            let cleanGreeting = viewModel.city.country.localGreeting
                .replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            
            if soundManager.isSpeaking {
                soundManager.stopSpeaking()
            } else {
                soundManager.speakGreeting(cleanGreeting, for: viewModel.city.country)
            }
            
            HapticManager.shared.trigger(.selection)
        }) {
            HStack(spacing: 8) {
                Image(systemName: soundManager.isSpeaking ? "speaker.wave.3.circle.fill" : "speaker.wave.2.circle.fill")
                    .modifier(BounceEffectModifier(shouldBounce: soundManager.isSpeaking))
                Text("Hear Greeting")
            }
            .font(.caption.bold())
            .foregroundColor(isHighContrast ? .primary : .adventureOrange)
        }
        .buttonStyle(.plain)
    }
    
    var currencySwapButton: some View {
        Button(action: {
            withAnimation(.spring()) {
                viewModel.isSwapped.toggle()
            }
            HapticManager.shared.trigger(.impact)
        }) {
            Label(viewModel.isSwapped ? "Local → Home" : "Home → Local", systemImage: "arrow.left.arrow.right.circle")
                .font(.caption.bold())
        }
        .buttonStyle(.borderedProminent)
        .tint(isHighContrast ? .primary : .adventureOrange)
        .buttonBorderShape(.capsule)
    }
    
    var currencyConverterStack: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                // Input Side
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.isSwapped ? "Local (\(viewModel.city.details.currencyCode))" : "Home (\(viewModel.selectedHomeCurrency))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    TextField("1.00", text: $viewModel.userBaseAmount)
                        .keyboardType(.decimalPad)
                        .font(.title3.bold())
                        .padding(8)
                        .background(isHighContrast ? Color.clear : Color(.systemGray6))
                        .overlay(isHighContrast ? Rectangle().stroke(Color.primary, lineWidth: 2) : nil)
                        .cornerRadius(8)
                }
                
                Image(systemName: "equal")
                    .foregroundStyle(.tertiary)
                    .font(.body.bold())
                    .padding(.top, 16)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(viewModel.isSwapped ? "Home (\(viewModel.selectedHomeCurrency))" : "Local (\(viewModel.city.details.currencyCode))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Text(viewModel.convertAmount(viewModel.userBaseAmount))
                        .font(.title3.bold())
                        .foregroundColor(isHighContrast ? .primary : .adventureOrange)
                        .frame(height: 44)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(isHighContrast ? Color.clear : Color.adventureOrange.opacity(0.05))
        .overlay(isHighContrast ? RoundedRectangle(cornerRadius: 12).stroke(Color.primary, lineWidth: 2) : nil)
        .cornerRadius(12)
    }
}


// MARK: - VERSION COMPATIBILITY MODIFIERS
struct BounceEffectModifier: ViewModifier {
    let shouldBounce: Bool
    
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.symbolEffect(.bounce, options: .repeating, value: shouldBounce)
        } else {
            content
                .scaleEffect(shouldBounce ? 1.2 : 1.0)
                .animation(shouldBounce ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true) : .default, value: shouldBounce)
        }
    }
}

struct PulseEffectModifier: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.symbolEffect(.pulse, options: .repeating, value: isActive)
        } else {
            content
                .opacity(isActive ? 0.5 : 1.0)
                .animation(isActive ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default, value: isActive)
        }
    }
}
