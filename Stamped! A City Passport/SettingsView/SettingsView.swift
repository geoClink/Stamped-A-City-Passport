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
                feedbackSection
                dangerZoneSection
            }
            .navigationTitle(L.Settings.title)
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
                Section(L.Settings.title) {
                    Label(L.Settings.experience, systemImage: "hand.tap").tag(SettingsTab.experience)
                }

                Section(L.Settings.maintenance) {
                    Label(L.Settings.resetProgress, systemImage: "trash")
                        .foregroundColor(viewModel.highContrast ? .primary : .red)
                        .tag(SettingsTab.danger)
                }
            }
            .navigationTitle(L.Settings.title)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L.Settings.back) { dismiss() }
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
            case .none: Text(L.Settings.selectSetting).foregroundColor(.secondary)
            }
        }
        .navigationTitle(selectedTab == .danger ? L.Settings.resetProgress : L.Settings.experience)
    }
}

// MARK: - Sub-Sections
private extension SettingsView {

    var experienceSection: some View {
        Section(header: Text(L.Settings.appExperience).fontWeight(viewModel.highContrast ? .bold : .regular)) {

            VStack(alignment: .leading, spacing: 8) {
                Label(L.Settings.measurementUnits, systemImage: "ruler")
                    .font(.subheadline)
                    .fontWeight(viewModel.highContrast ? .bold : .medium)

                Picker(L.Settings.unitSystem, selection: $viewModel.useMetric) {
                    Text(L.Settings.meters).tag(true)
                    Text(L.Settings.feet).tag(false)
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 8)

            Group {
                SettingsToggleRow(title: L.Settings.soundEffects, icon: "speaker.wave.2.fill", isOn: $viewModel.isSoundEnabled, isHighContrast: viewModel.highContrast)
                SettingsToggleRow(title: L.Settings.haptics, icon: "iphone.radiowaves.left.and.right", isOn: $viewModel.hapticsEnabled, isHighContrast: viewModel.highContrast)
                SettingsToggleRow(title: L.Settings.highContrast, icon: "circle.lefthalf.filled", isOn: $viewModel.highContrast, isHighContrast: viewModel.highContrast)
                SettingsToggleRow(title: L.Settings.reduceMotion, icon: "slowmo", isOn: $viewModel.reduceMotion, isHighContrast: viewModel.highContrast)
            }

            HStack(spacing: 15) {
                Image(systemName: "wifi.slash")
                    .font(.title2)
                    .foregroundColor(viewModel.highContrast ? .primary : .green)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L.Settings.offlineReady)
                        .font(.subheadline.bold())
                    Text(L.Settings.offlineReadyBody)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L.Settings.preview)
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
                    Button(L.Settings.testMotion) {
                        withAnimation(viewModel.reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.6)) {
                            moveRight.toggle()
                        }
                    }
                    .buttonStyle(PreviewButtonStyle(isHighContrast: viewModel.highContrast, color: .blue))

                    Button(L.Settings.testSound) {
                        viewModel.playSoundPreview()
                    }
                    .buttonStyle(PreviewButtonStyle(isHighContrast: viewModel.highContrast, color: viewModel.brandColor))
                }
            }
            .padding(.vertical, 12)
        }
        .tint(viewModel.highContrast ? .primary : viewModel.brandColor)
    }

    var feedbackSection: some View {
        Section(header: Text("Feedback & Support").fontWeight(viewModel.highContrast ? .bold : .regular)) {
            feedbackLink(
                title: "Report Incorrect Info",
                subtitle: "Wrong building details, photos, or descriptions",
                icon: "exclamationmark.bubble.fill",
                iconColor: .orange,
                subject: "Content Issue Report",
                body: "Building name:\nCity:\nWhat's wrong:\n"
            )
            feedbackLink(
                title: "Suggest a Building",
                subtitle: "Know a landmark we're missing?",
                icon: "plus.bubble.fill",
                iconColor: .blue,
                subject: "Building Suggestion",
                body: "City:\nBuilding name:\nAddress:\nWhy it should be included:\n"
            )
            feedbackLink(
                title: "General Feedback",
                subtitle: "Ideas, bugs, or anything else",
                icon: "envelope.fill",
                iconColor: .green,
                subject: "Stamped App Feedback",
                body: ""
            )
        }
    }

    private func feedbackLink(title: String, subtitle: String, icon: String, iconColor: Color, subject: String, body: String) -> some View {
        // Replace georgeclinkscalesdev@proton.me with your support email address
        let email = "georgeclinkscalesdev@proton.me"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)"

        return Group {
            if let url = URL(string: urlString) {
                Link(destination: url) {
                    feedbackRow(title: title, subtitle: subtitle, icon: icon, iconColor: iconColor)
                }
                .foregroundColor(.primary)
            } else {
                feedbackRow(title: title, subtitle: subtitle, icon: icon, iconColor: iconColor)
            }
        }
    }

    private func feedbackRow(title: String, subtitle: String, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(viewModel.highContrast ? .primary : iconColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(viewModel.highContrast ? .bold : .medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }

    var dangerZoneSection: some View {
        Section {
            Button(role: .destructive) {
                showingFirstAlert = true
            } label: {
                Text(L.Settings.resetAllContent)
                    .fontWeight(viewModel.highContrast ? .black : .bold)
                    .foregroundColor(viewModel.highContrast ? .primary : .red)
                    .frame(maxWidth: .infinity)
            }
        } footer: {
            Text(L.Settings.version)
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
            .alert(L.Settings.resetFirstTitle, isPresented: isFirstPresented) {
                Button(L.CityDetail.cancel, role: .cancel) { }
                Button(L.Settings.resetFirstContinue) { isFinalPresented.wrappedValue = true }
            } message: {
                Text(L.Settings.resetFirstMessage)
            }
            .alert(L.Settings.resetFinalTitle, isPresented: isFinalPresented) {
                Button(L.Settings.resetFinalConfirm, role: .destructive) {
                    viewModel.resetAllContent()
                }
                Button(L.Settings.resetFinalCancel, role: .cancel) { }
            } message: {
                Text(L.Settings.resetFinalMessage)
            }
    }
}
