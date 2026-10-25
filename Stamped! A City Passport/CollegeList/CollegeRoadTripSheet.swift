//
//  CollegeRoadTripSheet.swift
//  Stamped! A City Passport
//
//  "Plan a College Road Trip": pick which schools on My College List to
//  visit (all of them to start with), see the driving order, and make one
//  trip with a day per campus. Each day is that campus's landmarks in
//  walking order, like "Plan a Campus Visit". The trip itself is made by
//  TripStore.collegeRoadTrip(for:).
//

import SwiftUI

struct CollegeRoadTripSheet: View {
    /// The schools to choose from, in the order of the user's list.
    let campuses: [CityLocation.City]
    /// Called with the new (or already made) trip after the sheet closes itself.
    let onCreate: (Trip) -> Void

    @ObservedObject private var tripStore = TripStore.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("high_contrast_mode") private var isHighContrast = false
    @State private var selected: Set<CityLocation.City>

    init(campuses: [CityLocation.City], onCreate: @escaping (Trip) -> Void) {
        self.campuses = campuses
        self.onCreate = onCreate
        _selected = State(initialValue: Set(campuses))
    }

    /// The chosen schools in list order; the first one is where the trip starts.
    private var chosen: [CityLocation.City] {
        campuses.filter { selected.contains($0) }
    }

    /// The chosen schools in driving order.
    private var route: [CityLocation.City] {
        TripStore.roadTripOrder(chosen)
    }

    private var alreadyMade: Bool {
        tripStore.existingCollegeRoadTrip(for: route) != nil
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(campuses) { campus in
                        schoolRow(campus)
                    }
                } header: {
                    DSSectionHeader("Schools to Visit", systemImage: "graduationcap", isHighContrast: isHighContrast)
                } footer: {
                    Text(NSLocalizedString("One day per school, each a walking tour of its landmarks.", comment: "College road trip planner: footer under the list of schools"))
                }

                if !route.isEmpty {
                    Section {
                        ForEach(Array(route.enumerated()), id: \.element) { index, campus in
                            routeRow(campus, index: index)
                        }
                    } header: {
                        DSSectionHeader("Driving Order", systemImage: "car", isHighContrast: isHighContrast)
                    } footer: {
                        Text(String(
                            format: NSLocalizedString("Starts at %@, then always drives to the closest school left. Distances are straight-line.", comment: "College road trip planner: footer explaining the driving order; %@ is the first school"),
                            route[0].name
                        ))
                    }
                }
            }
            .navigationTitle(NSLocalizedString("College Road Trip", comment: "Trip planner: place label for a trip that visits several campuses"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "College road trip planner: closes without making a trip")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(alreadyMade
                           ? NSLocalizedString("Open", comment: "College road trip planner: opens the road trip already made for these schools")
                           : NSLocalizedString("Create", comment: "College road trip planner: makes the road trip")) {
                        createTrip()
                    }
                    .disabled(chosen.isEmpty)
                }
            }
            .tint(DS.Palette.accent)
        }
    }

    // MARK: - Rows

    private func schoolRow(_ campus: CityLocation.City) -> some View {
        let isOn = selected.contains(campus)
        return Button {
            if isOn {
                selected.remove(campus)
            } else {
                selected.insert(campus)
            }
            HapticManager.shared.trigger(.selection)
        } label: {
            HStack(spacing: DS.Space.m) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? (isHighContrast ? Color.primary : DS.Palette.accent) : Color.secondary)
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text(campus.name)
                        // Serif, the style guide's type for destinations
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.primary)
                    Text(String(
                        format: NSLocalizedString("%d landmarks", comment: "College list: number of landmarks on a campus, e.g. \"12 landmarks\""),
                        campus.buildings.count
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func routeRow(_ campus: CityLocation.City, index: Int) -> some View {
        HStack(spacing: DS.Space.m) {
            StopNumberBadge(number: index + 1, isLandmark: true)
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text(String(
                    format: NSLocalizedString("Day %1$d: %2$@", comment: "College road trip planner: one day of the route, e.g. \"Day 2: Duke University\""),
                    index + 1, campus.name
                ))
                if index > 0 {
                    let previous = route[index - 1]
                    Text(String(
                        format: NSLocalizedString("%1$@ from %2$@", comment: "College road trip planner: distance from the previous school, e.g. \"12 mi from Duke\""),
                        Self.distanceText(meters: TripStore.meters(from: previous, to: campus)),
                        previous.campusVisitShortName
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// "12 mi" or "19 km", in the user's units.
    static func distanceText(meters: Double) -> String {
        Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    // MARK: - Actions

    private func createTrip() {
        guard let trip = tripStore.collegeRoadTrip(for: chosen) else { return }
        HapticManager.shared.trigger(.success)
        dismiss()
        onCreate(trip)
    }
}

#Preview {
    CollegeRoadTripSheet(campuses: [.duke, .uncChapelHill, .wakeForest, .ncState]) { _ in }
}
