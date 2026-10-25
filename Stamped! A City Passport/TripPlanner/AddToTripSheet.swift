//
//  AddToTripSheet.swift
//  Stamped! A City Passport
//
//  "Add to Trip" from the map: pick one of the city's trips and a day,
//  or start a new trip. Used by the landmark card, saved-place card and
//  Apple's place card.
//

import SwiftUI

struct AddToTripSheet: View {
    let cityName: String
    /// What's being added (a landmark or a saved place).
    let stop: TripStop.Kind
    /// Shown in the title, e.g. "Empire State Building".
    let stopName: String

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = TripStore.shared
    @AppStorage("haptics_enabled") private var hapticsEnabled = true
    @AppStorage("high_contrast_mode") private var isHighContrast = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var addedTo: String?

    private var trips: [Trip] { store.trips(in: cityName) }

    var body: some View {
        NavigationStack {
            List {
                ForEach(trips) { trip in
                    Section {
                        ForEach(Array(trip.days.enumerated()), id: \.element.id) { index, day in
                            Button {
                                add(to: day.id, in: trip, dayNumber: index + 1)
                            } label: {
                                HStack(spacing: DS.Space.s) {
                                    // The stop count goes under the day at accessibility sizes
                                    let layout = dynamicTypeSize.isAccessibilitySize
                                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.xs))
                                        : AnyLayout(HStackLayout(spacing: DS.Space.s))
                                    layout {
                                        Text(dayTitle(trip: trip, index: index))
                                            .foregroundStyle(.primary)
                                        if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                                        Text(day.stops.isEmpty ? "Empty" : day.stops.count == 1 ? "1 stop" : "\(day.stops.count) stops")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if dynamicTypeSize.isAccessibilitySize { Spacer() }
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(DS.Palette.accent)
                                }
                            }
                        }
                        Button {
                            if let newDay = store.addDay(to: trip.id) {
                                add(to: newDay, in: trip, dayNumber: trip.days.count + 1)
                            }
                        } label: {
                            Label("Add to a New Day", systemImage: "calendar.badge.plus")
                        }
                    } header: {
                        // Interpolated so the trip's name shows as is, not looked up as a key
                        DSSectionHeader("\(trip.name)", systemImage: "suitcase", isHighContrast: isHighContrast)
                    }
                }

                Section {
                    Button {
                        let trip = store.createTrip(name: "\(cityName) Trip", cityName: cityName)
                        if let firstDay = trip.days.first {
                            add(to: firstDay.id, in: trip, dayNumber: 1)
                        }
                    } label: {
                        Label(trips.isEmpty ? "Start a \(cityName) Trip" : "New Trip",
                              systemImage: "suitcase.rolling.fill")
                    }
                }
            }
            .navigationTitle("Add to Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .top) {
                Text(stopName)
                    // Serif, the style guide's type for destinations
                    .font(.system(.headline, design: .serif))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.top, DS.Space.xs)
                    .dsPageMargin()
            }
            // Brief confirmation, then close
            .overlay {
                if let addedTo {
                    Label("Added to \(addedTo)", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .padding(DS.Space.l)
                        .background(.regularMaterial, in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .presentationDetents([.medium, .large])
        // Solid background, so the map card underneath doesn't show through the glass
        .presentationBackground(Color(UIColor.systemGroupedBackground))
    }

    private func dayTitle(trip: Trip, index: Int) -> String {
        if let date = trip.date(ofDayAt: index) {
            return "Day \(index + 1) · \(date.formatted(.dateTime.weekday(.abbreviated).month().day()))"
        }
        return "Day \(index + 1)"
    }

    private func add(to dayID: String, in trip: Trip, dayNumber: Int) {
        store.addStop(stop, toDay: dayID, in: trip.id)
        if hapticsEnabled { HapticManager.shared.trigger(.success) }
        withAnimation(.spring) { addedTo = "\(trip.name), Day \(dayNumber)" }
        Task {
            try? await Task.sleep(for: .seconds(0.9))
            dismiss()
        }
    }
}

/// Lets `.sheet(item:)` present the Add to Trip sheet for one stop.
struct AddToTripRequest: Identifiable {
    let id = UUID()
    let stop: TripStop.Kind
    let name: String
}
