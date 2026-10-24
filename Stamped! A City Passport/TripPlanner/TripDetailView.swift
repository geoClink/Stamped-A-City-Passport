//
//  TripDetailView.swift
//  Stamped! A City Passport
//
//  One trip: a map of the chosen day's route, then each day as a section
//  of stops in walking order, with the walk time to the next stop.
//  Drag to reorder, swipe to delete, and "Optimize route" to sort a day
//  by nearest stop.
//
//  Also shows anywhere trips (2.5). Those have no city page behind them, so
//  `viewModel` is nil: no landmarks, no 3D tour, and stops come from Apple Maps.
//

import SwiftUI
import MapKit

struct TripDetailView: View {
    let tripID: String
    /// Passed on to the map when this trip's Tour opens it.
    /// nil for an anywhere trip, which isn't in a Stamped city.
    let viewModel: CityDetailViewModel?

    /// The city's landmarks, or none for an anywhere trip.
    private var buildings: [Building] { viewModel?.city.buildings ?? [] }

    @ObservedObject private var store = TripStore.shared
    @ObservedObject private var progress = GlobalProgressManager.shared
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// The day shown on the route map. nil means the first day.
    @State private var mapDayID: String?
    @State private var showingTour = false

    /// The day the "Add Stop" picker is adding to.
    @State private var addingToDay: TripDay?
    @State private var showingRename = false
    @State private var renameText = ""
    /// The stop the "Move to Day" dialog is open for.
    @State private var movingStop: MovingStop?

    private struct MovingStop: Identifiable {
        let stopID: String
        let name: String
        let fromDayID: String
        var id: String { stopID }
    }

    private var trip: Trip? { store.trip(withID: tripID) }

    /// The 3D map, flying through this trip. Opened by "Tour This Trip".
    @ViewBuilder
    private var tourMap: some View {
        if let viewModel {
            NavigationStack {
                CityMapView(buildings: viewModel.city.buildings, cityName: viewModel.city.name, viewModel: viewModel, tripToTour: tripID)
            }
        }
    }

    /// Same as the city page's map: a sheet on iPhone, full screen on iPad.
    private func tourPresented(fullScreen: Bool) -> Binding<Bool> {
        Binding(
            get: { showingTour && (sizeClass == .regular) == fullScreen },
            set: { showingTour = $0 }
        )
    }

    var body: some View {
        if let trip {
            tripList(trip)
                .task(id: trip.id) { await repairAreaIfNeeded(trip) }
        } else {
            // The trip was deleted (here or on another device)
            ContentUnavailableView("Trip Not Found", systemImage: "suitcase")
        }
    }

    private func tripList(_ trip: Trip) -> some View {
        List {
            routeMapSection(trip)

            Section {
                startDateRow(trip)
            }

            ForEach(Array(trip.days.enumerated()), id: \.element.id) { index, day in
                daySection(day, index: index, in: trip)
            }

            Section {
                Button {
                    store.addDay(to: trip.id)
                    HapticManager.shared.trigger(.selection)
                } label: {
                    Label("Add Day", systemImage: "calendar.badge.plus")
                }
            }
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                EditButton()
                Menu {
                    Button {
                        renameText = trip.name
                        showingRename = true
                    } label: {
                        Label("Rename Trip", systemImage: "pencil")
                    }
                    Button {
                        store.addDay(to: trip.id)
                    } label: {
                        Label("Add Day", systemImage: "calendar.badge.plus")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: tourPresented(fullScreen: false)) { tourMap }
        .fullScreenCover(isPresented: tourPresented(fullScreen: true)) { tourMap }
        .sheet(item: $addingToDay) { day in
            if let viewModel {
                AddTripStopSheet(city: viewModel.city, tripID: trip.id, dayID: day.id)
            } else {
                AnywhereStopSheet(trip: trip, dayID: day.id)
            }
        }
        .confirmationDialog(
            "Move \(movingStop?.name ?? "stop") to…",
            isPresented: Binding(get: { movingStop != nil }, set: { if !$0 { movingStop = nil } }),
            titleVisibility: .visible,
            presenting: movingStop
        ) { moving in
            ForEach(Array(trip.days.enumerated()), id: \.element.id) { index, otherDay in
                if otherDay.id != moving.fromDayID {
                    Button("Day \(index + 1)") {
                        withAnimation {
                            store.moveStop(moving.stopID, toDay: otherDay.id, in: trip.id)
                        }
                    }
                }
            }
        }
        .alert("Rename Trip", isPresented: $showingRename) {
            TextField("Trip name", text: $renameText)
            Button("Save") { store.renameTrip(trip.id, to: renameText) }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Route map

    private func routeMapSection(_ trip: Trip) -> some View {
        // Fall back to the first day if the chosen day was removed
        let day = trip.days.first { $0.id == mapDayID } ?? trip.days[0]
        let stops = ResolvedTripStop.resolve(day, buildings: buildings, customPlaces: progress.customPlaces)

        return Section {
            TripRouteMap(stops: stops, cityCenter: mapCenter(for: trip))
                // A taller map on iPad, where there's room for it
                .frame(height: sizeClass == .regular ? 340 : 220)
                .listRowInsets(EdgeInsets())

            if trip.days.count > 1 {
                let selection = Binding(get: { day.id }, set: { mapDayID = $0 })
                // Segmented fits a few days; a menu handles a long trip
                if trip.days.count <= 5 {
                    dayPicker(trip, selection: selection)
                        .pickerStyle(.segmented)
                } else {
                    dayPicker(trip, selection: selection)
                        .pickerStyle(.menu)
                }
            }

            // The 3D tour needs a Stamped city's map, so anywhere trips skip it for now
            if viewModel != nil {
                tourButton(trip)
            }
        }
    }

    private func tourButton(_ trip: Trip) -> some View {
        Button {
            showingTour = true
        } label: {
            // HStack rather than Label: inside a List row, Label can drop its icon
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text("Tour This Trip in 3D")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.adventureOrange)
        // Needs at least one stop with a location to fly to
        .disabled(TripTour.steps(for: trip, buildings: buildings, customPlaces: progress.customPlaces).isEmpty)
        .accessibilityHint("Opens the 3D map and flies through each day's stops in order")
    }

    /// Where the map starts before any stops are added: the middle of the
    /// city's landmarks, or the searched area for an anywhere trip.
    private func mapCenter(for trip: Trip) -> CLLocationCoordinate2D? {
        if viewModel != nil {
            return TripRouteMap.center(of: buildings)
        }
        return trip.area?.coordinate
    }

    /// An anywhere trip should always have an area. If an older app version
    /// re-saved the trip it drops the "area" key, so look the name up again.
    private func repairAreaIfNeeded(_ trip: Trip) async {
        guard trip.listedCity == nil, trip.area == nil else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trip.cityName
        request.resultTypes = .address
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else { return }
        let coordinate = item.displayCoordinate
        store.setArea(
            TripArea(name: item.name ?? trip.cityName, latitude: coordinate.latitude, longitude: coordinate.longitude),
            for: trip.id
        )
    }

    private func dayPicker(_ trip: Trip, selection: Binding<String>) -> some View {
        Picker("Day on map", selection: selection) {
            ForEach(Array(trip.days.enumerated()), id: \.element.id) { index, day in
                Text("Day \(index + 1)").tag(day.id)
            }
        }
    }

    // MARK: - Start date

    @ViewBuilder
    private func startDateRow(_ trip: Trip) -> some View {
        // A Binding that turns the optional date on and off with a toggle
        let hasDate = Binding(
            get: { trip.startDate != nil },
            set: { isOn in
                store.setStartDate(isOn ? Calendar.current.startOfDay(for: .now) : nil, for: trip.id)
            }
        )
        Toggle("Set Start Date", isOn: hasDate)
        if let startDate = trip.startDate {
            DatePicker(
                "Starts",
                selection: Binding(
                    get: { startDate },
                    set: { store.setStartDate($0, for: trip.id) }
                ),
                displayedComponents: .date
            )
        }
    }

    // MARK: - Day section

    private func daySection(_ day: TripDay, index: Int, in trip: Trip) -> some View {
        let stops = ResolvedTripStop.resolve(day, buildings: buildings, customPlaces: progress.customPlaces)
        let walkTimes = ResolvedTripStop.walkingMinutesToNext(stops)

        return Section {
            ForEach(Array(stops.enumerated()), id: \.element.id) { stopIndex, stop in
                TripStopRow(stop: stop, number: stopIndex + 1, walkMinutesToNext: walkTimes[stop.id])
                    // Long-press is taken by drag-to-reorder, so moving between days is a swipe
                    .swipeActions(edge: .leading) {
                        if trip.days.count > 1 {
                            Button {
                                movingStop = MovingStop(stopID: stop.id, name: stop.name, fromDayID: day.id)
                            } label: {
                                Label("Move", systemImage: "calendar")
                            }
                            .tint(Color.adventureOrange)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            store.removeStop(stop.id, fromDay: day.id, in: trip.id)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
            .onMove { source, destination in
                store.moveStops(inDay: day.id, in: trip.id, fromOffsets: source, toOffset: destination)
            }
            .onDelete { offsets in
                for offset in offsets {
                    store.removeStop(stops[offset].id, fromDay: day.id, in: trip.id)
                }
            }

            Button {
                addingToDay = day
            } label: {
                Label("Add Stop", systemImage: "plus.circle.fill")
                    .foregroundStyle(Color.adventureOrange)
            }
        } header: {
            TripDayHeader(
                dayNumber: index + 1,
                date: trip.date(ofDayAt: index),
                canOptimize: stops.count > 2,
                canRemove: trip.days.count > 1,
                onOptimize: {
                    let order = ResolvedTripStop.optimizedStopIDs(stops)
                    withAnimation {
                        store.reorderStops(order, inDay: day.id, in: trip.id)
                    }
                    HapticManager.shared.trigger(.success)
                },
                onRemove: {
                    withAnimation {
                        store.removeDay(day.id, from: trip.id)
                    }
                }
            )
        }
    }
}

/// "Day 2 · Tue, Oct 24" with the Optimize button and a menu to remove the day.
private struct TripDayHeader: View {
    let dayNumber: Int
    let date: Date?
    let canOptimize: Bool
    let canRemove: Bool
    let onOptimize: () -> Void
    let onRemove: () -> Void

    @State private var confirmingRemove = false

    var body: some View {
        HStack {
            Text("Day \(dayNumber)")
                .font(.headline)
                .foregroundStyle(.primary)
            if let date {
                Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if canOptimize {
                Button(action: onOptimize) {
                    Label("Optimize route", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .tint(Color.adventureOrange)
                .accessibilityHint("Reorders this day's stops so each one is the closest to the last")
            }
            if canRemove {
                Menu {
                    Button("Remove Day \(dayNumber)", systemImage: "trash", role: .destructive) {
                        confirmingRemove = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .padding(.leading, 8)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Day \(dayNumber) options")
            }
        }
        .textCase(nil)
        .confirmationDialog("Remove Day \(dayNumber) and its stops?", isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button("Remove Day", role: .destructive, action: onRemove)
        }
    }
}
