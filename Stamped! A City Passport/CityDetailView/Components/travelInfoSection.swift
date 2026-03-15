//
//  SwiftUIView.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI

struct TravelInfoSection: View {
    @ObservedObject var viewModel: CityDetailViewModel
    @FocusState private var isConverterFocused: Bool
    var isHighContrast: Bool
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Accessible Color Palette
    private var primaryText: Color { .primary }
    private var descriptiveText: Color {
        // Use semantic secondary label so the color adapts to Light/Dark modes and accessibility
        if isHighContrast {
            return .primary
        }
        // In dark mode the default secondaryLabel can be too low-contrast against some backgrounds.
        // Use a slightly stronger primary-based color to ensure readability while keeping subtlety.
        if colorScheme == .dark {
            return Color.primary.opacity(0.85)
        }
        // In light mode use pure black to guarantee >= 4.5:1 contrast against white backgrounds.
        return Color.black
    }
    private var accentColor: Color {
        isHighContrast ? .primary : .adventureOrange
    }
    private var cardBackground: Color {
        isHighContrast ? Color(UIColor.systemBackground) : Color(.secondarySystemGroupedBackground)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TRAVEL DOSSIER")
                .font(.system(.caption, design: .monospaced).bold())
                .tracking(2)
                .foregroundColor(descriptiveText)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)

            if horizontalSizeClass == .regular {
                ipadLayout
            } else {
                iphoneLayout
            }
        }
        .onTapGesture { isConverterFocused = false }
    }

    // MARK: - Layouts
    
    @ViewBuilder
    private var ipadLayout: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 24)], spacing: 24) {
            allTiles
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var iphoneLayout: some View {
        VStack(spacing: 0) {
            travelDisclosure(title: "Language", value: viewModel.city.details.language, icon: "bubble.left", info: viewModel.city.details.languageInfo, subTitle: "Greeting: \(viewModel.city.country.localGreeting)", isLanguage: true)
            customDivider
            travelDisclosure(title: "Airport", value: viewModel.city.details.airportCode, icon: "airplane", info: viewModel.city.details.airportInfo, subTitle: viewModel.city.details.airportName)
            customDivider
            travelDisclosure(title: "Transportation", value: viewModel.city.details.transportation, icon: "tram.fill", info: viewModel.city.details.transportationFact, subTitle: "Local Transit")
            customDivider
            travelDisclosure(title: "Currency", value: viewModel.currencyText, icon: "dollarsign.circle", info: viewModel.city.details.currencyInfo, binding: $viewModel.userBaseAmount)
            customDivider
        }
        .background(cardBackground)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 3))
        .padding(.horizontal)
    }

    @ViewBuilder
    private var allTiles: some View {
        infoTile(title: "Language", value: viewModel.city.details.language, icon: "bubble.left.and.bubble.right.fill", info: viewModel.city.details.languageInfo, subTitle: "Greeting: \(viewModel.city.country.localGreeting)", isLanguage: true)
        
        infoTile(title: "Main Airport", value: viewModel.city.details.airportCode, icon: "airplane.circle.fill", info: viewModel.city.details.airportInfo, subTitle: viewModel.city.details.airportName)
        
        infoTile(title: "Transportation", value: viewModel.city.details.transportation, icon: "tram.circle.fill", info: viewModel.city.details.transportationFact, subTitle: "City Transit")
        
        infoTile(title: "Currency", value: viewModel.currencyText, icon: "arrow.left.arrow.right.circle.fill", info: viewModel.city.details.currencyInfo, binding: $viewModel.userBaseAmount)
    }

    // MARK: - Components
    
    @ViewBuilder
    private func infoTile(title: String, value: String, icon: String, info: String, subTitle: String? = nil, isLanguage: Bool = false, binding: Binding<String>? = nil) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title.uppercased())
                        .font(.caption2.bold())
                        .foregroundColor(descriptiveText)
                    Text(value)
                        .font(.title2.bold())
                        .foregroundColor(primaryText)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(accentColor)
            }
            .padding(.bottom, 16)
            
            if let sub = subTitle {
                HStack(spacing: 8) {
                    Text(sub)
                        .font(.subheadline.bold())
                        .foregroundColor(primaryText)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if isLanguage {
                        Button { handleSpeechAction() } label: {
                            Image(systemName: "speaker.wave.2.circle.fill")
                                .font(.title3)
                        }
                        .foregroundColor(accentColor)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 12)
            }
            
            Text(info)
                .font(.footnote)
                .lineSpacing(4)
                .foregroundColor(descriptiveText)
                .minimumScaleFactor(0.9)
                .lineLimit(nil)
            
            Spacer(minLength: 16)
            
            if title == "Currency", let amountBinding = binding {
                QuickConverterView(viewModel: viewModel, userAmount: amountBinding)
                    .focused($isConverterFocused)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 300)
        .background(cardBackground)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(isHighContrast ? 0 : 0.05), radius: 10, y: 4)
    }

    @ViewBuilder
    private func travelDisclosure(title: String, value: String, icon: String, info: String, subTitle: String? = nil, isLanguage: Bool = false, binding: Binding<String>? = nil) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                Text(info)
                    .font(.footnote)
                    .foregroundColor(descriptiveText)
                
                if title == "Currency", let amountBinding = binding {
                    QuickConverterView(viewModel: viewModel, userAmount: amountBinding)
                        .focused($isConverterFocused)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(accentColor.opacity(0.1)))
            .padding(.horizontal, 12).padding(.bottom, 12)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon).font(.title3.bold()).foregroundColor(accentColor).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.caption.bold()).foregroundColor(descriptiveText)
                    Text(value).font(.body.bold()).foregroundColor(primaryText)
                    if let sub = subTitle {
                        HStack {
                            Text(sub).font(.caption2.bold()).foregroundColor(descriptiveText)
                            if isLanguage {
                                Button { handleSpeechAction() } label: { Image(systemName: "speaker.wave.2.circle.fill") }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(.vertical, 10)
        }
        .padding(.horizontal)
    }

    private var customDivider: some View {
        Divider()
            .background(isHighContrast ? Color.primary : Color.gray.opacity(0.4))
            .padding(.leading, 56)
    }

    private func handleSpeechAction() {
        let raw = viewModel.city.country.localGreeting
        let clean = raw.replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        SoundManager.shared.speakGreeting(clean, for: viewModel.city.country)
    }
}
