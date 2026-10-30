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
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    @State private var moveRight = false
    @State private var showingFirstAlert = false
    @State private var showingFinalAlert = false
    @State private var selectedTab: SettingsTab? = .experience
    @ObservedObject private var offline = OfflineDownloader.shared

    enum SettingsTab: Hashable {
        case experience, offline, danger
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
                offlineSection
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
                            .foregroundColor(viewModel.highContrast ? .primary : DS.Palette.accent)
                    }
                }
            }
        }
    }

    /// Top-left on iPad. A Mac sheet doesn't show the leading spot, so there it goes with the sheet's buttons.
    static var backButtonPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .confirmationAction
        #else
        .navigationBarLeading
        #endif
    }

    var ipadLayout: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section(L.Settings.title) {
                    Label(L.Settings.experience, systemImage: "hand.tap").tag(SettingsTab.experience)
                    Label("Saved for Offline", systemImage: "arrow.down.circle").tag(SettingsTab.offline)
                }

                Section(L.Settings.maintenance) {
                    Label(L.Settings.resetProgress, systemImage: "trash")
                        .foregroundColor(viewModel.highContrast ? .primary : .red)
                        .tag(SettingsTab.danger)
                }
            }
            .navigationTitle(L.Settings.title)
            .toolbar {
                ToolbarItem(placement: Self.backButtonPlacement) {
                    Button(L.Settings.back) { dismiss() }
                        .fontWeight(viewModel.highContrast ? .black : .bold)
                        .foregroundColor(viewModel.highContrast ? .primary : DS.Palette.accent)
                }
            }
        } detail: {
            detailView
        }
    }

    private var detailTitle: String {
        switch selectedTab {
        case .danger: return L.Settings.resetProgress
        case .offline: return NSLocalizedString("Saved for Offline", comment: "Settings: list of cities saved for offline use")
        default: return L.Settings.experience
        }
    }

    @ViewBuilder
    private var detailView: some View {
        Form {
            switch selectedTab {
            case .experience: experienceSection
            case .offline: offlineSection
            case .danger: dangerZoneSection
            case .none: Text(L.Settings.selectSetting).foregroundColor(.secondary)
            }
        }
        .navigationTitle(detailTitle)
    }
}

// MARK: - Sub-Sections
private extension SettingsView {

    var experienceSection: some View {
        Section(header: Text(L.Settings.appExperience).fontWeight(viewModel.highContrast ? .bold : .regular)) {

            VStack(alignment: .leading, spacing: DS.Space.s) {
                Label {
                    Text(L.Settings.measurementUnits)
                        .fontWeight(viewModel.highContrast ? .bold : .medium)
                } icon: {
                    rowIcon("ruler")
                }

                Picker(L.Settings.unitSystem, selection: $viewModel.useMetric) {
                    Text(L.Settings.meters).tag(true)
                    Text(L.Settings.feet).tag(false)
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, DS.Space.s)

            Group {
                SettingsToggleRow(title: L.Settings.soundEffects, icon: "speaker.wave.2.fill", isOn: $viewModel.isSoundEnabled, isHighContrast: viewModel.highContrast)
                SettingsToggleRow(title: L.Settings.haptics, icon: "iphone.radiowaves.left.and.right", isOn: $viewModel.hapticsEnabled, isHighContrast: viewModel.highContrast)
                SettingsToggleRow(title: L.Settings.highContrast, icon: "circle.lefthalf.filled", isOn: $viewModel.highContrast, isHighContrast: viewModel.highContrast)
                SettingsToggleRow(title: L.Settings.reduceMotion, icon: "slowmo", isOn: $viewModel.reduceMotion, isHighContrast: viewModel.highContrast)
            }

            // The date picker drops below the label at accessibility sizes
            rowLayout {
                Label {
                    rowText(title: Text("Birthday"), subtitle: Text("Used for the Birthday Stamp achievement"))
                } icon: {
                    rowIcon("gift.fill")
                }
                Spacer(minLength: 0)
                if viewModel.hasBirthday {
                    DatePicker("", selection: Binding(
                        get: { viewModel.birthday },
                        set: { viewModel.birthday = $0 }
                    ), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                } else {
                    Button("Set") { viewModel.birthday = Date() }
                        .foregroundStyle(viewModel.brandColor)
                        .fontWeight(.semibold)
                }
            }
            .padding(.vertical, DS.Space.xs)

            Label {
                rowText(title: Text(L.Settings.offlineReady), subtitle: Text(L.Settings.offlineReadyBody))
            } icon: {
                rowIcon("wifi.slash")
            }
            .padding(.vertical, DS.Space.xs)

            VStack(spacing: DS.Space.l) {
                VStack(alignment: .leading, spacing: DS.Space.m) {
                    Text(L.Settings.preview)
                        .font(.caption2.weight(.black))
                        .foregroundColor(viewModel.highContrast ? .primary : .secondary)

                    ZStack(alignment: moveRight ? .trailing : .leading) {
                        Capsule()
                            .fill(viewModel.highContrast ? Color.primary.opacity(0.15) : Color.primary.opacity(0.05))
                            .frame(height: 36)
                            .overlay(Capsule().stroke(viewModel.highContrast ? Color.primary : Color.clear, lineWidth: 2))

                        Image(systemName: "airplane")
                            .foregroundColor(viewModel.highContrast ? .primary : DS.Palette.accent)
                            .padding(.horizontal, DS.Space.m)
                    }
                }

                // Side by side normally, stacked at accessibility sizes
                let buttonLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: DS.Space.m))
                    : AnyLayout(HStackLayout(spacing: DS.Space.m))
                buttonLayout {
                    Button(L.Settings.testMotion) {
                        withAnimation(viewModel.reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.6)) {
                            moveRight.toggle()
                        }
                    }
                    .buttonStyle(PreviewButtonStyle(isHighContrast: viewModel.highContrast, color: viewModel.brandColor))

                    Button(L.Settings.testSound) {
                        viewModel.playSoundPreview()
                    }
                    .buttonStyle(PreviewButtonStyle(isHighContrast: viewModel.highContrast, color: viewModel.brandColor))
                }
            }
            .padding(.vertical, DS.Space.m)
        }
        .tint(viewModel.highContrast ? .primary : viewModel.brandColor)
    }

    /// Cities saved with "Save for Offline" on their page, with their size and Remove
    var offlineSection: some View {
        Section {
            if offline.savedCities.isEmpty {
                Text("No cities saved yet. Open a city or campus and tap Save for Offline in its Plan tab.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, DS.Space.xs)
            } else {
                ForEach(offline.savedCities) { record in
                    rowLayout {
                        Label {
                            rowText(title: Text(record.cityName), subtitle: Text(OfflineSaveSection.detail(for: record)))
                        } icon: {
                            rowIcon("checkmark.circle.fill")
                        }
                        Spacer(minLength: 0)
                        Button("Remove", role: .destructive) {
                            offline.remove(cityID: record.cityID)
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(viewModel.highContrast ? .primary : .red)
                        .accessibilityLabel(Text(String(format: NSLocalizedString("Remove %@", comment: "Settings, Saved for Offline: VoiceOver label for removing a city's offline copy"), record.cityName)))
                    }
                    .padding(.vertical, DS.Space.xs)
                }
            }
        } header: {
            Text("Saved for Offline").fontWeight(viewModel.highContrast ? .bold : .regular)
        } footer: {
            Text("Maps aren't saved. For an offline map, download the area in Apple Maps (Offline Maps).")
        }
    }

    var feedbackSection: some View {
        Section(
            header: Text("Feedback & Support").fontWeight(viewModel.highContrast ? .bold : .regular),
            footer: Text(CampusDisclaimer.text)
        ) {
            feedbackLink(
                title: "Report Incorrect Info",
                subtitle: "Wrong building details, photos, or descriptions",
                icon: "exclamationmark.bubble.fill",
                subject: "Content Issue Report",
                body: "Building name:\nCity:\nWhat's wrong:\n"
            )
            feedbackLink(
                title: "Suggest a Building",
                subtitle: "Know a landmark we're missing?",
                icon: "plus.bubble.fill",
                subject: "Building Suggestion",
                body: "City:\nBuilding name:\nAddress:\nWhy it should be included:\n"
            )
            feedbackLink(
                title: "General Feedback",
                subtitle: "Ideas, bugs, or anything else",
                icon: "envelope.fill",
                subject: "Stamped App Feedback",
                body: "",
                isSuggestion: false
            )
        }
    }

    /// Corrections and building ideas carry the suggestion tag (so they're filed with the website's);
    /// general feedback doesn't.
    private func feedbackLink(title: LocalizedStringKey, subtitle: LocalizedStringKey, icon: String, subject: String, body: String, isSuggestion: Bool = true) -> some View {
        let url = isSuggestion
            ? FeedbackMail.general(subject: subject, body: body)
            : URL(string: "mailto:\(FeedbackMail.address)?subject=\(FeedbackMail.encoded(subject))&body=\(FeedbackMail.encoded(body + "\n\n" + FeedbackMail.appInfo))")

        return Group {
            if let url {
                Link(destination: url) {
                    feedbackRow(title: title, subtitle: subtitle, icon: icon)
                }
                .foregroundColor(.primary)
            } else {
                feedbackRow(title: title, subtitle: subtitle, icon: icon)
            }
        }
    }

    private func feedbackRow(title: LocalizedStringKey, subtitle: LocalizedStringKey, icon: String) -> some View {
        HStack(spacing: DS.Space.m) {
            Label {
                rowText(title: Text(title), subtitle: Text(subtitle))
            } icon: {
                rowIcon(icon)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, DS.Space.xs)
    }

    // MARK: Row pieces

    /// Row icons share the Label icon column and the accent color, like the toggle rows
    func rowIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .foregroundColor(viewModel.highContrast ? .primary : DS.Palette.accent)
    }

    func rowText(title: Text, subtitle: Text) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            title
                .fontWeight(viewModel.highContrast ? .bold : .medium)
            subtitle
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    /// A row that puts its trailing control under the label at accessibility sizes
    func rowLayout<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.s))
            : AnyLayout(HStackLayout(spacing: DS.Space.m))
        return layout { content() }
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
                    .foregroundColor(isHighContrast ? .primary : DS.Palette.accent)
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
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .multilineTextAlignment(.center)
            .padding(.vertical, DS.Space.m)
            .padding(.horizontal, DS.Space.s)
            .background(isHighContrast ? (isDark ? Color.white : Color.black) : color.opacity(0.12))
            .foregroundColor(isHighContrast ? (isDark ? Color.black : Color.white) : color)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
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
