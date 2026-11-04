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
    /// The system's Reduce Motion, on top of the app's own setting below
    @Environment(\.accessibilityReduceMotion) var systemReduceMotion

    @State private var moveRight = false
    @State private var showingFirstAlert = false
    @State private var showingFinalAlert = false
    @State private var selectedTab: SettingsTab? = .preferences
    @ObservedObject private var offline = OfflineDownloader.shared

    /// The iPad and Mac sidebar rows, in the same order as the iPhone list's sections
    enum SettingsTab: Hashable {
        case preferences, passport, offline, support, feedback, about, danger
    }

    /// The Stamped! privacy policy on the website (the same page the App Store listing links to)
    private static let privacyPolicyURL = URL(string: "https://georgeclinkscalesdev.com/stamped-privacy.html")!

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
                preferencesSection
                passportSection
                offlineSection
                supportSection
                feedbackSection
                aboutSection
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
                            // The chevron alone is 18 pt wide; 44 is Apple's smallest comfortable tap target
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    // Icon-only, so VoiceOver needs the word
                    .accessibilityLabel(L.Settings.back)
                }
            }
        }
    }

    var ipadLayout: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                // No header here: the navigation title already says "Settings"
                Section {
                    Label("Preferences", systemImage: "slider.horizontal.3").tag(SettingsTab.preferences)
                    Label("Your Passport", systemImage: "person.text.rectangle").tag(SettingsTab.passport)
                    Label("Offline", systemImage: "arrow.down.circle").tag(SettingsTab.offline)
                    Label("Support Stamped!", systemImage: "heart").tag(SettingsTab.support)
                    Label("Feedback", systemImage: "envelope").tag(SettingsTab.feedback)
                    Label("About", systemImage: "info.circle").tag(SettingsTab.about)
                }

                Section(L.Settings.maintenance) {
                    Label(L.Settings.resetProgress, systemImage: "trash")
                        .foregroundColor(viewModel.highContrast ? .primary : .red)
                        .tag(SettingsTab.danger)
                }
            }
            .navigationTitle(L.Settings.title)
            .toolbar {
                // "Done" on the trailing side, like the app's other full-screen modals
                // (.confirmationAction is also where a Mac sheet puts its buttons)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(viewModel.highContrast ? .black : .bold)
                        .foregroundColor(viewModel.highContrast ? .primary : DS.Palette.accent)
                }
            }
        } detail: {
            detailView
        }
        // Tinting the whole split view (not just one section) makes the
        // selected sidebar row brand orange instead of system blue
        .tint(viewModel.highContrast ? .primary : viewModel.brandColor)
    }

    private var detailTitle: String {
        switch selectedTab {
        case .danger: return L.Settings.resetProgress
        case .passport: return NSLocalizedString("Your Passport", comment: "Settings: section with the traveler's birthday")
        case .offline: return NSLocalizedString("Offline", comment: "Settings: section listing cities saved for offline use")
        case .support: return NSLocalizedString("Support Stamped!", comment: "Settings: tip jar")
        case .feedback: return NSLocalizedString("Feedback", comment: "Settings: section with email links for corrections, suggestions and feedback")
        case .about: return NSLocalizedString("About", comment: "Settings: section with the app version, disclaimer and privacy policy")
        default: return NSLocalizedString("Preferences", comment: "Settings: section with units, sound, haptics, contrast and motion")
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if selectedTab == .support {
            // The tip jar has its own scrolling layout (not a Form) and its own title
            TipJarView()
                .tint(viewModel.highContrast ? .primary : viewModel.brandColor)
        } else {
            settingsForm
        }
    }

    private var settingsForm: some View {
        Form {
            switch selectedTab {
            case .preferences: preferencesSection
            case .passport: passportSection
            case .offline: offlineSection
            case .feedback: feedbackSection
            case .about: aboutSection
            case .danger: dangerZoneSection
            case .support: EmptyView()   // shown by detailView instead
            case .none: Text(L.Settings.selectSetting).foregroundColor(.secondary)
            }
        }
        .navigationTitle(detailTitle)
    }
}

// MARK: - Sub-Sections
private extension SettingsView {

    /// Units, sound, haptics, contrast and motion, with Test Motion and Test Sound right below them
    var preferencesSection: some View {
        Section(header: Text("Preferences").fontWeight(viewModel.highContrast ? .bold : .regular)) {

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
                    // A visual demo of the animation; the Test Motion button below is what VoiceOver needs
                    .accessibilityHidden(true)
                }

                // Side by side normally, stacked at accessibility sizes
                let buttonLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: DS.Space.m))
                    : AnyLayout(HStackLayout(spacing: DS.Space.m))
                buttonLayout {
                    Button(L.Settings.testMotion) {
                        withAnimation(viewModel.reduceMotion || systemReduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.6)) {
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

    /// About the traveler: the birthday that unlocks the Birthday Stamp achievement
    var passportSection: some View {
        Section(header: Text("Your Passport").fontWeight(viewModel.highContrast ? .bold : .regular)) {
            // The date picker drops below the label at accessibility sizes
            rowLayout {
                Label {
                    rowText(title: Text("Birthday"), subtitle: Text("Used for the Birthday Stamp achievement"))
                } icon: {
                    rowIcon("gift.fill")
                }
                Spacer(minLength: 0)
                if viewModel.hasBirthday {
                    // Labelled (then hidden) so VoiceOver says what the date is for
                    DatePicker("Birthday", selection: Binding(
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
            Text("Offline").fontWeight(viewModel.highContrast ? .bold : .regular)
        } footer: {
            Text("Maps aren't saved. For an offline map, download the area in Apple Maps (Offline Maps).")
        }
    }

    var feedbackSection: some View {
        Section(header: Text("Feedback").fontWeight(viewModel.highContrast ? .bold : .regular)) {
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

    /// iPhone: opens the tip jar (iPad and Mac show it from the sidebar instead)
    var supportSection: some View {
        Section {
            NavigationLink {
                TipJarView()
                    .tint(viewModel.highContrast ? .primary : viewModel.brandColor)
            } label: {
                Label {
                    rowText(title: Text("Support Stamped!"), subtitle: Text("Tips help keep new cities coming"))
                } icon: {
                    rowIcon("heart.fill")
                }
                .padding(.vertical, DS.Space.xs)
            }
        }
    }

    /// The app version and privacy policy, with the university disclaimer underneath
    var aboutSection: some View {
        Section {
            Label {
                Text(L.Settings.version)
                    .fontWeight(viewModel.highContrast ? .bold : .medium)
            } icon: {
                rowIcon("info.circle.fill")
            }
            .padding(.vertical, DS.Space.xs)

            Link(destination: Self.privacyPolicyURL) {
                feedbackRow(title: "Privacy Policy", subtitle: "How Stamped! handles your data", icon: "hand.raised.fill")
            }
            .foregroundColor(.primary)
        } header: {
            Text("About").fontWeight(viewModel.highContrast ? .bold : .regular)
        } footer: {
            Text(CampusDisclaimer.text)
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
                .accessibilityHidden(true)
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
        }
    }
}

// MARK: - Components
struct SettingsToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    let isHighContrast: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Toggle(isOn: $isOn) {
            // At the largest text sizes the icon and the switch left the words too little room
            // ("Haptics" broke in the middle), so the words get the whole row
            if dynamicTypeSize.isAccessibilitySize {
                titleText
            } else {
                Label {
                    titleText
                } icon: {
                    Image(systemName: icon)
                        .foregroundColor(isHighContrast ? .primary : DS.Palette.accent)
                }
            }
        }
    }

    private var titleText: some View {
        Text(title).fontWeight(isHighContrast ? .bold : .medium)
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
