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
//  College road trips are anywhere trips too (`viewModel` is nil), but each day
//  is one campus's landmarks. Their landmarks are looked up across every city,
//  "Add Stop" offers the day's campus landmarks, and the 3D tour flies through
//  the campus of the day shown on the map.
//
//  Hotels: a road trip day gets "Hotels near <campus>" for that night; any other
//  trip gets one "Find Hotels" for its city and dates (see Hotels/HotelLinks.swift).
//

import SwiftUI
import MapKit

struct TripDetailView: View {
    let tripID: String
    /// Passed on to the map when this trip's Tour opens it.
    /// nil for an anywhere trip, which isn't in a Stamped city.
    let viewModel: CityDetailViewModel?

    /// The city's landmarks. An anywhere trip has none, except a college road
    /// trip, whose landmarks come from several campuses.
    private var buildings: [Building] { viewModel?.city.buildings ?? trip?.landmarkBuildings ?? [] }

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
        } else if let campus = roadTripTourCity {
            // A campus's map only knows its own landmarks, so the tour flies
            // through that campus's day and skips the other campuses' days
            RoadTripTourMap(city: campus, tripID: tripID)
        }
    }

    /// For a college road trip: the campus of the day shown on the route map,
    /// which is the campus the 3D tour opens.
    private var roadTripTourCity: CityLocation.City? {
        guard viewModel == nil, let trip, trip.isRoadTrip else { return nil }
        let dayIndex = trip.days.firstIndex { $0.id == mapDayID } ?? 0
        return trip.city(ofDayAt: dayIndex)
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

            // A road trip finds hotels day by day, in each day's section instead
            if !trip.isRoadTrip, let search = hotelSearch(for: trip) {
                Section {
                    FindHotelsButton(search: search, opensInApp: false)
                        .tint(DS.Palette.accent)
                }
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
            } else if trip.isRoadTrip, let campus = roadTripCity(ofDay: day.id, in: trip) {
                // A road trip day adds from its own campus's landmarks
                AddTripStopSheet(city: campus, tripID: trip.id, dayID: day.id)
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

    /// The campus (or city) a road trip day is at, from its landmarks.
    private func roadTripCity(ofDay dayID: String, in trip: Trip) -> CityLocation.City? {
        guard let index = trip.days.firstIndex(where: { $0.id == dayID }) else { return nil }
        return trip.city(ofDayAt: index)
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

            // The 3D tour needs a Stamped city's map, so anywhere trips skip it for now.
            // A college road trip tours the campus of the day on the map.
            if viewModel != nil {
                tourButton(trip, title: Text("Tour This Trip in 3D"), buildings: buildings)
            } else if let campus = roadTripTourCity {
                tourButton(
                    trip,
                    title: Text(String(
                        format: NSLocalizedString("Tour %@ in 3D", comment: "College road trip: button that opens the 3D tour of one day's campus, e.g. \"Tour Duke in 3D\""),
                        campus.campusVisitShortName
                    )),
                    buildings: campus.buildings
                )
            }
        }
    }

    private func tourButton(_ trip: Trip, title: Text, buildings: [Building]) -> some View {
        Button {
            showingTour = true
        } label: {
            // HStack rather than Label: inside a List row, Label can drop its icon
            HStack(spacing: DS.Space.s) {
                Image(systemName: "play.fill")
                title
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
        }
        // The trip's one primary action: filled orange, like every primary button
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(DS.Palette.accent)
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
        return trip.area?.coordinate ?? TripRouteMap.center(of: buildings)
    }

    /// An anywhere trip should always have an area. If an older app version
    /// re-saved the trip it drops the "area" key, so look the name up again.
    private func repairAreaIfNeeded(_ trip: Trip) async {
        guard trip.listedCity == nil, trip.area == nil else { return }
        // A road trip's label isn't a place to search for; use its first campus
        if trip.isRoadTrip {
            if let campus = trip.roadTripCampuses.first {
                store.setArea(TripArea(name: campus.name, latitude: campus.coordinate.lat, longitude: campus.coordinate.lon), for: trip.id)
            }
            return
        }
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

    // MARK: - Hotels

    /// Hotels for the whole trip: its city (or searched area), from the start date
    /// to the morning after the last day. No dates when the trip has no start date.
    private func hotelSearch(for trip: Trip) -> HotelSearch? {
        let checkIn = trip.startDate
        let checkOut = trip.date(ofDayAt: trip.days.count)
        if let city = trip.listedCity {
            return HotelSearch(city: city, checkIn: checkIn, checkOut: checkOut)
        }
        guard let area = trip.area else { return nil }
        return HotelSearch(destination: trip.cityName, coordinate: area.coordinate, checkIn: checkIn, checkOut: checkOut)
    }

    /// "Hotels near Duke" for the night of a road trip day, checking out the next morning.
    @ViewBuilder
    private func roadTripHotelsButton(dayAt index: Int, in trip: Trip) -> some View {
        if trip.isRoadTrip, let campus = trip.city(ofDayAt: index) {
            FindHotelsButton(
                search: HotelSearch(city: campus, checkIn: trip.date(ofDayAt: index), checkOut: trip.date(ofDayAt: index + 1)),
                title: String(
                    format: NSLocalizedString("Hotels near %@", comment: "College road trip: button that opens a hotel search for the night of one day's campus, e.g. \"Hotels near Duke\""),
                    campus.campusVisitShortName
                ),
                opensInApp: false
            )
            .tint(DS.Palette.accent)
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
                            .tint(DS.Palette.accent)
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
                    .foregroundStyle(DS.Palette.accent)
            }

            roadTripHotelsButton(dayAt: index, in: trip)
        } header: {
            TripDayHeader(
                dayNumber: index + 1,
                date: trip.date(ofDayAt: index),
                // Road trips: which campus this day is at
                placeName: trip.isRoadTrip ? trip.city(ofDayAt: index)?.name : nil,
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

/// The 3D map of one campus on a college road trip. Like My Trips' city trips,
/// the city page normally owns the view model, so this view makes one and keeps it.
private struct RoadTripTourMap: View {
    let city: CityLocation.City
    let tripID: String
    @StateObject private var viewModel: CityDetailViewModel

    init(city: CityLocation.City, tripID: String) {
        self.city = city
        self.tripID = tripID
        _viewModel = StateObject(wrappedValue: CityDetailViewModel(city: city))
    }

    var body: some View {
        NavigationStack {
            CityMapView(buildings: city.buildings, cityName: city.name, viewModel: viewModel, tripToTour: tripID)
        }
    }
}

/// "Day 2 · Tue, Oct 24" with the Optimize button and a menu to remove the day.
private struct TripDayHeader: View {
    let dayNumber: Int
    let date: Date?
    var placeName: String? = nil
    let canOptimize: Bool
    let canRemove: Bool
    let onOptimize: () -> Void
    let onRemove: () -> Void

    @State private var confirmingRemove = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Day and place on top, the actions on their own line: side by side, a campus name
    /// got cut off and "Optimize route" broke over three lines with large text.
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
                // At accessibility sizes the date goes under "Day 2" so neither gets squeezed
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        dayTitle
                        dateText
                    }
                } else {
                    dayTitle
                    dateText
                }
                Spacer(minLength: DS.Space.s)
                if canRemove {
                    Menu {
                        Button("Remove Day \(dayNumber)", systemImage: "trash", role: .destructive) {
                            confirmingRemove = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .padding(.leading, DS.Space.s)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Day \(dayNumber) options")
                }
            }
            if let placeName {
                Label(placeName, systemImage: "graduationcap.fill")
                    // Serif, the style guide's type for destinations
                    .font(.system(.subheadline, design: .serif))
                    // The list already dims section headers; .secondary on top made it unreadable
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if canOptimize {
                Button(action: onOptimize) {
                    Label("Optimize route", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                // Secondary action: bordered, next to the filled Tour button above
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(DS.Palette.accent)
                .accessibilityHint("Reorders this day's stops so each one is the closest to the last")
            }
        }
        .textCase(nil)
        .padding(.top, DS.Space.s)
        .confirmationDialog("Remove Day \(dayNumber) and its stops?", isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button("Remove Day", role: .destructive, action: onRemove)
        }
    }

    private var dayTitle: some View {
        Text("Day \(dayNumber)")
            .font(.headline)
            .foregroundStyle(.primary)
    }

    @ViewBuilder
    private var dateText: some View {
        if let date {
            // Monospaced, like the style guide's micro-labels
            Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .font(.subheadline.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}
