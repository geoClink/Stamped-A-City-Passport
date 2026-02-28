//
//  SwiftUIView.swift
//  Stamped
//
//  Created by George Clinkscales on 1/13/26.
//
import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.colorScheme) var colorScheme
    
    @State private var moveRight = false
    @State private var showingFirstAlert = false
    @State private var showingFinalAlert = false
    @State private var selectedTab: SettingsTab? = .experience

    enum SettingsTab: Hashable {
        case experience, danger
    }

    var body: some View {
        ZStack {
            if horizontalSizeClass == .regular {
                ipadLayout
            } else {
                iphoneLayout
            }
        }
        .alertFlow(isFirstPresented: $showingFirstAlert, isFinalPresented: $showingFinalAlert, viewModel: viewModel)
    }
}

// MARK: - Layouts
private extension SettingsView {
    
    var iphoneLayout: some View {
        NavigationStack {
            List {
                experienceSection
                dangerZoneSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(viewModel.highContrast ? .black : .medium)
                            .foregroundColor(viewModel.highContrast ? .primary : .accentColor)
                    }
                }
            }
        }
    }

    var ipadLayout: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section("Settings") {
                    Label("Experience", systemImage: "hand.tap").tag(SettingsTab.experience)
                }
                
                Section("Maintenance") {
                    Label("Reset Progress", systemImage: "trash")
                        .foregroundColor(viewModel.highContrast ? .primary : .red)
                        .tag(SettingsTab.danger)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                        .fontWeight(viewModel.highContrast ? .black : .bold)
                        .foregroundColor(viewModel.highContrast ? .primary : .accentColor)
                }
            }
        } detail: {
            detailView
        }
    }

    @ViewBuilder
    private var detailView: some View {
        Form {
            switch selectedTab {
            case .experience: experienceSection
            case .danger: dangerZoneSection
            case .none: Text("Select a setting").foregroundColor(.secondary)
            }
        }
        .navigationTitle(selectedTab == .danger ? "Reset Progress" : "Experience")
    }
}

// MARK: - Sub-Sections
private extension SettingsView {
    
    var experienceSection: some View {
        Section(header: Text("App Experience").fontWeight(viewModel.highContrast ? .bold : .regular)) {
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Measurement Units", systemImage: "ruler")
                    .font(.subheadline)
                    .fontWeight(viewModel.highContrast ? .bold : .medium)
                
                Picker("Unit System", selection: $viewModel.useMetric) {
                    Text("Meters").tag(true)
                    Text("Feet").tag(false)
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 8)

            Group {
                SettingsToggleRow(title: "Sound Effects", icon: "speaker.wave.2.fill", isOn: $viewModel.isSoundEnabled, isHighContrast: viewModel.highContrast)
                SettingsToggleRow(title: "Haptics", icon: "iphone.radiowaves.left.and.right", isOn: $viewModel.hapticsEnabled, isHighContrast: viewModel.highContrast)
                SettingsToggleRow(title: "High Contrast", icon: "circle.lefthalf.filled", isOn: $viewModel.highContrast, isHighContrast: viewModel.highContrast)
                SettingsToggleRow(title: "Reduce Motion", icon: "slowmo", isOn: $viewModel.reduceMotion, isHighContrast: viewModel.highContrast)
            }

            HStack(spacing: 15) {
                Image(systemName: "wifi.slash")
                    .font(.title2)
                    .foregroundColor(viewModel.highContrast ? .primary : .green)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Offline Ready")
                        .font(.subheadline.bold())
                    Text("Full Library & Itineraries available offline.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("PREVIEW")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(viewModel.highContrast ? .primary : .secondary)
                    
                    ZStack(alignment: moveRight ? .trailing : .leading) {
                        Capsule()
                            .fill(viewModel.highContrast ? Color.primary.opacity(0.15) : Color.primary.opacity(0.05))
                            .frame(height: 36)
                            .overlay(Capsule().stroke(viewModel.highContrast ? Color.primary : Color.clear, lineWidth: 2))
                        
                        Image(systemName: "airplane")
                            .foregroundColor(viewModel.highContrast ? .primary : .blue)
                            .padding(.horizontal, 12)
                    }
                }
                
                HStack(spacing: 12) {
                    Button("Test Motion") {
                        withAnimation(viewModel.reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.6)) {
                            moveRight.toggle()
                        }
                    }
                    .buttonStyle(PreviewButtonStyle(isHighContrast: viewModel.highContrast, color: .blue))
                    
                    Button("Test Sound") {
                        viewModel.playSoundPreview()
                    }
                    .buttonStyle(PreviewButtonStyle(isHighContrast: viewModel.highContrast, color: viewModel.brandColor))
                }
            }
            .padding(.vertical, 12)
        }
        .tint(viewModel.highContrast ? .primary : viewModel.brandColor)
    }

    var dangerZoneSection: some View {
        Section {
            Button(role: .destructive) {
                showingFirstAlert = true
            } label: {
                Text("Reset All Content")
                    .fontWeight(viewModel.highContrast ? .black : .bold)
                    .foregroundColor(viewModel.highContrast ? .primary : .red)
                    .frame(maxWidth: .infinity)
            }
        } footer: {
            Text("Version 1.0 (Build 2026)")
                .font(.caption2)
                .foregroundColor(viewModel.highContrast ? .primary : .secondary)
        }
    }
}

// MARK: - Components
struct SettingsToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    let isHighContrast: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label {
                Text(title).fontWeight(isHighContrast ? .bold : .medium)
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(isHighContrast ? .primary : .accentColor)
            }
        }
    }
}

struct PreviewButtonStyle: ButtonStyle {
    let isHighContrast: Bool
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let isDark = colorScheme == .dark
        
        configuration.label
            .font(.caption.bold())
            .fontWeight(isHighContrast ? .black : .bold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isHighContrast ? (isDark ? Color.white : Color.black) : color.opacity(0.12))
            .foregroundColor(isHighContrast ? (isDark ? Color.black : Color.white) : color)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHighContrast ? (isDark ? Color.white : Color.black) : Color.clear, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
    }
}

// MARK: - Extensions
extension View {
    func alertFlow(isFirstPresented: Binding<Bool>, isFinalPresented: Binding<Bool>, viewModel: SettingsViewModel) -> some View {
        self
            .alert("Reset All Progress?", isPresented: isFirstPresented) {
                Button("Cancel", role: .cancel) { }
                Button("Continue") { isFinalPresented.wrappedValue = true }
            } message: {
                Text("Wipe visited buildings, passport stamps, and quiz scores.")
            }
            .alert("Final Warning", isPresented: isFinalPresented) {
                Button("Delete Everything", role: .destructive) {
                    viewModel.resetAllContent()
                }
                Button("Wait, Stop!", role: .cancel) { }
            } message: {
                Text("This action cannot be undone.")
            }
    }
}
