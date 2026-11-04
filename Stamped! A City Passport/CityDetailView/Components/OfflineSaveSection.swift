//
//  OfflineSaveSection.swift
//  Stamped! A City Passport
//
//  The "Offline Use" card on a city or campus page (Plan tab): Save for Offline,
//  progress while saving, the size once saved, and Remove. Maps can't be saved by
//  apps, so the card points to Apple Maps' own offline maps instead.
//

import SwiftUI

struct OfflineSaveSection: View {
    let city: CityLocation.City
    var isHighContrast: Bool

    @ObservedObject private var downloader = OfflineDownloader.shared
    @State private var confirmingRemove = false

    private var accent: Color { isHighContrast ? .primary : DS.Palette.accent }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader("Offline Use", systemImage: "arrow.down.circle", isHighContrast: isHighContrast)
                .dsPageMargin()

            VStack(alignment: .leading, spacing: DS.Space.m) {
                stateContent

                Text("Maps, weather, events and photo galleries still need a connection. For an offline map, download this area in Apple Maps (Offline Maps).")
                    .font(.footnote)
                    .foregroundStyle(isHighContrast ? Color.primary : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCard(isHighContrast: isHighContrast)
            .dsPageMargin()
        }
        .confirmationDialog(Text("Remove the offline copy of \(city.name)?"), isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { downloader.remove(cityID: city.id) }
        }
    }

    // MARK: - States

    @ViewBuilder
    private var stateContent: some View {
        switch downloader.status {
        case .saving(let cityID, let done, let total) where cityID == city.id:
            savingContent(done: done, total: total)
        case .saving:
            // Another city is saving; one at a time
            notSavedContent(disabled: true)
        default:
            if let record = downloader.record(for: city) {
                savedContent(record)
            } else {
                notSavedContent(disabled: false)
            }
        }
        if case .failed(let cityID, let failure) = downloader.status, cityID == city.id {
            Label(failureMessage(failure), systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(isHighContrast ? Color.primary : Color.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func notSavedContent(disabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            Text("Save the landmark photos and Wikipedia text to use without a connection, like on a flight.")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                HapticManager.shared.trigger(.selection)
                downloader.save(city)
            } label: {
                Label("Save for Offline", systemImage: "arrow.down.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .disabled(disabled)
            .accessibilityHint(Text(String(format: NSLocalizedString("Downloads photos and text for %d landmarks.", comment: "Offline card: VoiceOver hint for Save for Offline"), city.buildings.count)))
        }
    }

    private func savingContent(done: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            ProgressView(value: Double(done), total: Double(max(total, 1)))
                .tint(accent)
            Text(String(format: NSLocalizedString("Saving %d of %d…", comment: "Offline card: progress, e.g. Saving 12 of 17…"), done, total))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.primary)
            Button(role: .cancel) {
                downloader.cancel()
            } label: {
                Text(L.CityDetail.cancel)
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(accent)
            .accessibilityHint(Text("Stops saving. What's saved so far is kept for next time."))
        }
        .accessibilityElement(children: .contain)
    }

    private func savedContent(_ record: OfflineCityRecord) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saved for Offline")
                        .font(.subheadline.weight(.semibold))
                    Text(OfflineSaveSection.detail(for: record))
                        .font(.footnote)
                        .foregroundStyle(isHighContrast ? Color.primary : Color.secondary)
                }
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(isHighContrast ? Color.primary : Color.green)
            }
            .accessibilityElement(children: .combine)

            Button(role: .destructive) {
                confirmingRemove = true
            } label: {
                Label("Remove Offline Copy", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(isHighContrast ? .primary : .red)
            .accessibilityHint(Text("Deletes the saved photos and text from this device."))
        }
    }

    private func failureMessage(_ failure: OfflineDownloader.Failure) -> String {
        switch failure {
        case .connection:
            return NSLocalizedString("Couldn't finish saving. Check your connection and try again; what's saved so far is kept.", comment: "Offline card: the download failed")
        case .lowDataMode:
            return NSLocalizedString("Low Data Mode is on. Turn it off in Settings to save photos.", comment: "Offline card: the download stopped because of Low Data Mode")
        case .storage:
            return NSLocalizedString("Couldn't save to this device. Check that there's free storage.", comment: "Offline card: writing the files failed")
        }
    }

    /// "4.2 MB, saved Oct 30, 2026", shared with Settings
    static func detail(for record: OfflineCityRecord) -> String {
        let size = ByteCountFormatter.string(fromByteCount: record.byteCount, countStyle: .file)
        let date = record.savedAt.formatted(date: .abbreviated, time: .omitted)
        return String(format: NSLocalizedString("%1$@, saved %2$@", comment: "Offline copy: size and date, e.g. 4.2 MB, saved Oct 30, 2026"), size, date)
    }
}
