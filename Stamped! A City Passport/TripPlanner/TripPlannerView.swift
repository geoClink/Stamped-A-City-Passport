//
//  TripPlannerView.swift
//  Stamped! A City Passport
//
//  The trip planner for one city: a list of the city's trips, and the
//  selected trip's days and stops. On iPad both show side by side; on
//  iPhone the split view collapses into a normal push navigation.
//

import SwiftUI

struct TripPlannerView: View {
    /// The city page's view model, passed through so a trip's Tour can open the
    /// map (it needs it to stamp landmarks, like the city page's own map does).
    let viewModel: CityDetailViewModel

    private var city: CityLocation.City { viewModel.city }

    @ObservedObject private var store = TripStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTripID: String?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    /// Which column iPhone shows first: the trip itself when opened on one, else the list.
    @State private var compactColumn: NavigationSplitViewColumn = .sidebar
    @State private var showingNewTrip = false
    @State private var newTripName = ""

    private var cityTrips: [Trip] { store.trips(in: city.name) }

    /// Pass a trip id to open the planner on that trip (used by "Plan a Campus Visit").
    init(viewModel: CityDetailViewModel, initialTripID: String? = nil) {
        self.viewModel = viewModel
        _selectedTripID = State(initialValue: initialTripID)
        _compactColumn = State(initialValue: initialTripID == nil ? .sidebar : .detail)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $compactColumn) {
            tripList
        } detail: {
            if let selectedTripID {
                TripDetailView(tripID: selectedTripID, viewModel: viewModel)
                    // A fresh view per trip, so edit mode and sheets don't carry over
                    .id(selectedTripID)
            } else {
                ContentUnavailableView(
                    "No Trip Selected",
                    systemImage: "map",
                    description: Text("Pick a trip or create a new one.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(DS.Palette.accent)
        .alert("New Trip", isPresented: $showingNewTrip) {
            TextField("Trip name", text: $newTripName)
            Button("Create") { createTrip() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Give your \(city.name) trip a name.")
        }
    }

    // MARK: - Trip list

    private var tripList: some View {
        List(selection: $selectedTripID) {
            if cityTrips.isEmpty {
                ContentUnavailableView {
                    Label("No Trips Yet", systemImage: "suitcase")
                } description: {
                    Text("Plan your days in \(city.name): pick landmarks and saved places, then put them in walking order.")
                } actions: {
                    Button("Plan a Trip") { promptNewTrip() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(cityTrips) { trip in
                    NavigationLink(value: trip.id) {
                        TripSummaryRow(trip: trip)
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        deleteTrip(cityTrips[index].id)
                    }
                }
            }
        }
        .navigationTitle("\(city.name) Trips")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    promptNewTrip()
                } label: {
                    Label("New Trip", systemImage: "plus")
                }
            }
        }
    }

    // MARK: - Actions

    private func promptNewTrip() {
        newTripName = "\(city.name) Trip"
        showingNewTrip = true
    }

    private func createTrip() {
        let trip = store.createTrip(name: newTripName, cityName: city.name)
        HapticManager.shared.trigger(.success)
        selectedTripID = trip.id
    }

    private func deleteTrip(_ tripID: String) {
        if selectedTripID == tripID { selectedTripID = nil }
        store.deleteTrip(tripID)
    }
}

/// One trip in the list: an icon for the kind of trip, then name, day count and stop count.
/// Also used by My Trips, where anywhere trips show their area too
/// and college road trips their campuses.
struct TripSummaryRow: View {
    let trip: Trip
    var showsPlace = false

    @AppStorage("high_contrast_mode") private var isHighContrast = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 40

    /// Road trips drive, anywhere trips go worldwide, city trips follow a map route
    private var systemImage: String {
        if trip.isRoadTrip { return "car.fill" }
        if trip.listedCity == nil { return "globe.americas.fill" }
        return "point.topleft.down.to.point.bottomright.curvepath"
    }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Space.m) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(isHighContrast ? Color.primary : DS.Palette.accent)
                .frame(width: iconSize, height: iconSize)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                        .fill(isHighContrast ? Color.clear : DS.Palette.accent.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                        .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 1.5)
                )
                .accessibilityHidden(true)

            details
        }
        .padding(.vertical, DS.Space.xs)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(trip.name)
                .font(.headline)
            if showsPlace {
                // HStack rather than Label: in a List row, Label leaves a wide gap after the icon
                HStack(alignment: .firstTextBaseline, spacing: DS.Space.xs) {
                    if trip.isRoadTrip {
                        // A road trip's campuses, in driving order
                        Image(systemName: "graduationcap.fill")
                        Text(ListFormatter.localizedString(byJoining: trip.roadTripCampuses.map(\.campusVisitShortName)))
                            .lineLimit(2)
                    } else {
                        Image(systemName: "mappin.and.ellipse")
                        Text(trip.area?.name ?? trip.cityName)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(isHighContrast ? .primary : .secondary)
            }
            // Side by side normally; one fact per line at accessibility sizes so nothing breaks mid-word
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.xs))
                : AnyLayout(HStackLayout(spacing: DS.Space.s))
            layout {
                Text(trip.days.count == 1 ? "1 day" : "\(trip.days.count) days")
                separator
                Text(trip.stopCount == 1 ? "1 stop" : "\(trip.stopCount) stops")
                if let startDate = trip.startDate {
                    separator
                    Text(startDate, format: .dateTime.month(.abbreviated).day())
                }
            }
            .font(.subheadline)
            .foregroundStyle(isHighContrast ? .primary : .secondary)
        }
    }

    @ViewBuilder
    private var separator: some View {
        if !dynamicTypeSize.isAccessibilitySize {
            Text("·")
        }
    }
}

#Preview {
    TripPlannerView(viewModel: CityDetailViewModel(city: .boston))
}
