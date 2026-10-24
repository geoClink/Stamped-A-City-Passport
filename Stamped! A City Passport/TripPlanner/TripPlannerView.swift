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
    @State private var showingNewTrip = false
    @State private var newTripName = ""

    private var cityTrips: [Trip] { store.trips(in: city.name) }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
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
        .tint(Color.adventureOrange)
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

/// One trip in the list: name, day count and stop count.
private struct TripSummaryRow: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(trip.name)
                .font(.headline)
            HStack(spacing: 8) {
                Text(trip.days.count == 1 ? "1 day" : "\(trip.days.count) days")
                Text("·")
                Text(trip.stopCount == 1 ? "1 stop" : "\(trip.stopCount) stops")
                if let startDate = trip.startDate {
                    Text("·")
                    Text(startDate, format: .dateTime.month(.abbreviated).day())
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    TripPlannerView(viewModel: CityDetailViewModel(city: .boston))
}
