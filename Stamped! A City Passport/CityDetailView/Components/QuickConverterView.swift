//
//  SwiftUIView.swift
//  Stamped
//
//  Created by George Clinkscales on 2/1/26.
//
import SwiftUI

struct QuickConverterView: View {
    @ObservedObject var viewModel: CityDetailViewModel
    @Binding var userAmount: String
    @State private var showingCurrencyInfo = false
    @AppStorage("reduce_motion") var reduceMotion = false

    @AppStorage("high_contrast_mode") var isHighContrast = false
    
    // Use available currencies from view model to keep a single source of truth
    private var allCurrencies: [String] { viewModel.availableCurrencies }

    private var accentColor: Color {
        isHighContrast ? .primary : Color("adventureOrange")
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    headerLabel(isInput: true)
                    
                    TextField("1.00", text: $userAmount)
                        .keyboardType(.decimalPad)
                        .font(.title3.bold())
                        .padding(10)
                        .background(isHighContrast ? Color.clear : Color(.systemGray6))
                        .cornerRadius(isHighContrast ? 0 : 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: isHighContrast ? 0 : 10)
                                .stroke(Color.primary, lineWidth: isHighContrast ? 2 : 0)
                        )
                        .frame(minHeight: 44)
                        .accessibilityLabel("Amount to convert")
                }
                
                Button {
                    withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.6)) {
                        viewModel.isSwapped.toggle()
                        HapticManager.shared.trigger(.impact)
                    }
                    let from = viewModel.isSwapped ? viewModel.city.details.currencyCode : viewModel.selectedHomeCurrency
                    let to = viewModel.isSwapped ? viewModel.selectedHomeCurrency : viewModel.city.details.currencyCode
                    UIAccessibility.post(notification: .announcement, argument: "Swapped. Converting from \(from) to \(to)")
                } label: {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(accentColor)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.001))
                        .contentShape(Rectangle())
                }
                .padding(.top, 20)
                .accessibilityLabel("Swap conversion direction")
                .accessibilityHint("Currently converting from \(viewModel.isSwapped ? "Local" : "Home") to \(viewModel.isSwapped ? "Home" : "Local") currency.")
                
                VStack(alignment: .trailing, spacing: 6) {
                    headerLabel(isInput: false)
                    
                    Text(viewModel.convertAmount(userAmount))
                        .font(.title3.bold())
                        .foregroundColor(accentColor)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .frame(height: 44)
                        .padding(.horizontal, 4)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Converted amount")
                        .accessibilityValue(viewModel.convertAmount(userAmount))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .allowsTightening(true)
                        .layoutPriority(1)
                }
            }
            
            HStack(alignment: .center, spacing: 8) {
                // Tappable compact status icon (opens modal)
                Button { showingCurrencyInfo = true } label: {
                    Group {
                        switch viewModel.currencyMode {
                        case .live:
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(isHighContrast ? .primary : .green)
                        case .cached:
                            Image(systemName: "clock.fill")
                                .foregroundColor(accentColor)
                        case .offline:
                            Image(systemName: "wifi.slash")
                                .foregroundColor(isHighContrast ? .primary : .secondary)
                        }
                    }
                }
                .font(.caption2)
                .accessibilityLabel(NSLocalizedString("status.icon.accessibility", comment: "Accessibility label for currency status icon"))
                .accessibilityAddTraits(.isButton)

                // Status text (single source of truth)
                Text(viewModel.currencyStatusText)
                    .font(.caption2)
                    .italic()
                    .foregroundStyle(isHighContrast ? .primary : .secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                Spacer()

                // Refresh button + spinner
                Button {
                    Task { await viewModel.refreshRates() }
                } label: {
                    if viewModel.isFetchingRates {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 6)
                .accessibilityLabel(NSLocalizedString("refresh.rates.accessibility", comment: "Accessibility label for refresh rates button"))
                .accessibilityHint(NSLocalizedString("refresh.rates.hint", comment: "Accessibility hint for refresh rates button"))
            }
            .padding(.top, 4)
            .sheet(isPresented: $showingCurrencyInfo) {
                CurrencyInfoModal(viewModel: viewModel, isHighContrast: isHighContrast)
            }

            // Subtle inline accuracy note
            Text(NSLocalizedString("rates.disclaimer", comment: "Short disclaimer about currency accuracy"))
                .font(.caption2)
                .foregroundStyle(isHighContrast ? .primary : .secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(.top, 2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: isHighContrast ? 0 : 16)
                .fill(isHighContrast ? Color(UIColor.systemBackground) : accentColor.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: isHighContrast ? 0 : 16)
                .stroke(Color.primary, lineWidth: isHighContrast ? 3 : 0)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Currency Converter")
    }
    
    @ViewBuilder
    private func headerLabel(isInput: Bool) -> some View {
        let isLocal = isInput ? viewModel.isSwapped : !viewModel.isSwapped
        
        if isLocal {
            Text("Local (\(viewModel.city.details.currencyCode))")
                .font(.caption2.bold())
                .fontWeight(isHighContrast ? .black : .bold)
                .foregroundStyle(isHighContrast ? .primary : .secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
        } else {
            Menu {
                Picker("Home Currency", selection: $viewModel.selectedHomeCurrency) {
                    ForEach(allCurrencies, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Home (\(viewModel.selectedHomeCurrency))")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.caption2.bold())
                .fontWeight(isHighContrast ? .black : .bold)
                .textCase(.uppercase)
                .foregroundColor(accentColor)
            }
            .accessibilityLabel("Home currency: \(viewModel.selectedHomeCurrency)")
            .accessibilityHint("Double tap to change your home currency.")
        }
    }
}

// MARK: - Currency Info Modal
private struct CurrencyInfoModal: View {
    @ObservedObject var viewModel: CityDetailViewModel
    var isHighContrast: Bool
    @Environment(\.dismiss) var dismiss

    private var dateText: String {
        guard let d = viewModel.currencyUpdatedDate else { return NSLocalizedString("modal.never", comment: "Never updated") }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: d, relativeTo: Date())
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Group {
                        switch viewModel.currencyMode {
                        case .live:
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(isHighContrast ? .primary : .green)
                        case .cached:
                            Image(systemName: "clock.fill")
                                .foregroundColor(isHighContrast ? .primary : Color("adventureOrange"))
                        case .offline:
                            Image(systemName: "wifi.slash")
                                .foregroundColor(isHighContrast ? .primary : .secondary)
                        }
                    }
                    .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("modal.title", comment: "Title for currency info modal"))
                            .font(.headline)
                        Text("")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text(NSLocalizedString("modal.provider", comment: "Label for provider")); Spacer(); Text(viewModel.currencyProvider ?? "—") }
                    HStack { Text(NSLocalizedString("modal.last_updated", comment: "Label for last updated")); Spacer(); Text(dateText) }
                }
                .font(.subheadline)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.currencyMode == .live {
                        Text(NSLocalizedString("modal.explain_live", comment: "Explanation for live mode"))
                    } else if viewModel.currencyMode == .cached {
                        Text(NSLocalizedString("modal.explain_cached", comment: "Explanation for cached mode"))
                    } else {
                        Text(NSLocalizedString("modal.explain_offline", comment: "Explanation for offline mode"))
                    }
                }
                .font(.footnote)
                .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle(Text(NSLocalizedString("modal.header", comment: "Modal header")))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("modal.close", comment: "Close button")) { dismiss() }
                }
            }
        }
    }
}
