//
//  MyTripsView.swift
//  Stamped! A City Passport
//
//  Every trip in one place, opened from the home screen: trips planned
//  anywhere in the world, then trips in Stamped cities grouped by city.
//  "New Trip Anywhere" lives here. Same split layout as TripPlannerView.
//  College road trips (made from My College List) get their own section.
//

import SwiftUI

struct MyTripsView: View {
    @ObservedObject private var store = TripStore.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("high_contrast_mode") private var isHighContrast = false

    @State private var selectedTripID: String?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    /// Which column iPhone shows first: the trip itself when opened on one, else the list.
    @State private var compactColumn: NavigationSplitViewColumn = .sidebar
    @State private var showingAreaSearch = false

    /// Pass a trip id to open My Trips on that trip (used by "Plan a College Road Trip").
    init(initialTripID: String? = nil) {
        _selectedTripID = State(initialValue: initialTripID)
        _compactColumn = State(initialValue: initialTripID == nil ? .sidebar : .detail)
    }

    /// Listed-city trips grouped by city, cities in A–Z order.
    private var cityGroups: [(city: CityLocation.City, trips: [Trip])] {
        var groups: [CityLocation.City: [Trip]] = [:]
        for trip in store.trips {
            if let city = trip.listedCity {
                groups[city, default: []].append(trip)
            }
        }
        return groups
            .map { (city: $0.key, trips: $0.value) }
            .sorted { $0.city.name < $1.city.name }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $compactColumn) {
            tripList
        } detail: {
            if let selectedTripID, let trip = store.trip(withID: selectedTripID) {
                tripDetail(trip)
                    // A fresh view per trip, so edit mode and sheets don't carry over
                    .id(selectedTripID)
            } else {
                ContentUnavailableView(
                    "No Trip Selected",
                    systemImage: "map",
                    description: Text("Pick a trip or plan a new one anywhere.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(DS.Palette.accent)
        .sheet(isPresented: $showingAreaSearch) {
            AreaSearchSheet { trip in
                selectedTripID = trip.id
            }
        }
    }

    // MARK: - Trip list

    private var tripList: some View {
        List(selection: $selectedTripID) {
            if store.trips.isEmpty {
                ContentUnavailableView {
                    Label("No Trips Yet", systemImage: "suitcase")
                } description: {
                    Text("Plan a trip in a Stamped city from its page, or anywhere in the world from here.")
                } actions: {
                    Button("New Trip Anywhere") { showingAreaSearch = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
                .listRowBackground(Color.clear)
            }

            let roadTrips = store.collegeRoadTrips
            if !roadTrips.isEmpty {
                Section {
                    tripRows(roadTrips, showsPlace: true)
                } header: {
                    DSSectionHeader("College Road Trips", systemImage: "car.fill", isHighContrast: isHighContrast)
                }
            }

            let anywhereTrips = store.anywhereTrips
            if !anywhereTrips.isEmpty {
                Section {
                    tripRows(anywhereTrips, showsPlace: true)
                } header: {
                    DSSectionHeader("Anywhere", systemImage: "globe.americas.fill", isHighContrast: isHighContrast)
                }
            }

            ForEach(cityGroups, id: \.city) { group in
                Section {
                    tripRows(group.trips, showsPlace: false)
                } header: {
                    // Interpolated so the city name shows as is, not looked up as a key
                    DSSectionHeader("\(group.city.name)", systemImage: "building.2.fill", isHighContrast: isHighContrast)
                }
            }
        }
        .navigationTitle("My Trips")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAreaSearch = true
                } label: {
                    Label("New Trip Anywhere", systemImage: "plus")
                }
            }
        }
    }

    private func tripRows(_ trips: [Trip], showsPlace: Bool) -> some View {
        ForEach(trips) { trip in
            NavigationLink(value: trip.id) {
                TripSummaryRow(trip: trip, showsPlace: showsPlace)
            }
        }
        .onDelete { offsets in
            for index in offsets {
                deleteTrip(trips[index].id)
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private func tripDetail(_ trip: Trip) -> some View {
        if let city = trip.listedCity {
            ListedCityTripDetail(tripID: trip.id, city: city)
        } else {
            // No city page behind an anywhere trip, so no view model (and no 3D tour)
            TripDetailView(tripID: trip.id, viewModel: nil)
        }
    }

    private func deleteTrip(_ tripID: String) {
        if selectedTripID == tripID { selectedTripID = nil }
        store.deleteTrip(tripID)
    }
}

/// A Stamped-city trip opened from My Trips. The city page normally owns the
/// view model, so this view makes one and keeps it.
private struct ListedCityTripDetail: View {
    let tripID: String
    // @StateObject creates the view model once and keeps it across redraws,
    // like a property SwiftUI stores for you (a plain `let` would rebuild it every time).
    @StateObject private var viewModel: CityDetailViewModel

    init(tripID: String, city: CityLocation.City) {
        self.tripID = tripID
        _viewModel = StateObject(wrappedValue: CityDetailViewModel(city: city))
    }

    var body: some View {
        TripDetailView(tripID: tripID, viewModel: viewModel)
    }
}

#Preview {
    MyTripsView()
}
