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
    /// iPad tiles start this tall and grow with the text size
    @ScaledMetric(relativeTo: .body) private var tileMinHeight: CGFloat = 300
    /// Lines up row dividers with the row text, past the icon column
    private let dividerInset = DS.Space.l + 24 + DS.Space.l

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader("Travel Dossier", systemImage: "airplane", isHighContrast: isHighContrast)
                .dsPageMargin()

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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: DS.Space.xl)], spacing: DS.Space.xl) {
            allTiles
        }
        .dsPageMargin()
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
        }
        .dsCard(padding: 0, isHighContrast: isHighContrast)
        .dsPageMargin()
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
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text(title.uppercased())
                        .font(.caption2.bold())
                        .foregroundColor(descriptiveText)
                    Text(value)
                        .font(.title2.bold())
                        .foregroundColor(primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(accentColor)
            }
            .padding(.bottom, DS.Space.l)
            
            if let sub = subTitle {
                HStack(spacing: DS.Space.s) {
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
                .padding(.bottom, DS.Space.m)
            }
            
            Text(info)
                .font(.footnote)
                .lineSpacing(4)
                .foregroundColor(descriptiveText)
                .minimumScaleFactor(0.9)
                .lineLimit(nil)
            
            Spacer(minLength: DS.Space.l)
            
            if title == "Currency", let amountBinding = binding {
                QuickConverterView(viewModel: viewModel, userAmount: amountBinding)
                    .focused($isConverterFocused)
            }
        }
        // A minimum rather than a fixed height, so large text grows the tile instead of clipping
        .frame(maxWidth: .infinity, minHeight: tileMinHeight - 2 * DS.Space.l, alignment: .topLeading)
        .dsCard(isHighContrast: isHighContrast)
    }

    @ViewBuilder
    private func travelDisclosure(title: String, value: String, icon: String, info: String, subTitle: String? = nil, isLanguage: Bool = false, binding: Binding<String>? = nil) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                Text(info)
                    .font(.footnote)
                    .foregroundColor(descriptiveText)
                
                if title == "Currency", let amountBinding = binding {
                    QuickConverterView(viewModel: viewModel, userAmount: amountBinding)
                        .focused($isConverterFocused)
                }
            }
            .padding(DS.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous).fill(accentColor.opacity(0.1)))
            .padding(.bottom, DS.Space.m)
        } label: {
            HStack(spacing: DS.Space.l) {
                Image(systemName: icon).font(.title3.bold()).foregroundColor(accentColor).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.caption.bold()).foregroundColor(descriptiveText)
                    Text(value).font(.body.bold()).foregroundColor(primaryText)
                    if let sub = subTitle {
                        HStack(spacing: DS.Space.s) {
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
            .padding(.vertical, DS.Space.m)
        }
        .padding(.horizontal, DS.Space.l)
    }

    private var customDivider: some View {
        Divider()
            .background(isHighContrast ? Color.primary : Color.gray.opacity(0.4))
            .padding(.leading, dividerInset)
    }

    private func handleSpeechAction() {
        let raw = viewModel.city.country.localGreeting
        let clean = raw.replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        SoundManager.shared.speakGreeting(clean, for: viewModel.city.country)
    }
}
