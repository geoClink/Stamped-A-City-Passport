//
//  MacSupport.swift
//  Stamped! A City Passport
//
//  The Mac-only pieces of the window: the city workspace (3D map + details
//  inspector) and the menu bar commands. iPhone and iPad never use these.
//

import SwiftUI

/// Menu bar commands, passed to the main window through NavigationManager.
enum MenuCommand: Equatable {
    case search, passport, myJourney, myTrips, worldMap, achievements, collegeList, settings
}

#if os(macOS)

// MARK: - City workspace

/// The Mac's city screen: the photoreal 3D map fills the window and the city's
/// details (landmarks, quiz, trips, itinerary) sit in an inspector beside it.
struct MacCityWorkspace: View {
    let city: CityLocation.City
    @StateObject private var viewModel: CityDetailViewModel
    @AppStorage("mac_shows_city_details") private var showingDetails = true

    init(city: CityLocation.City) {
        self.city = city
        _viewModel = StateObject(wrappedValue: CityDetailViewModel(city: city))
    }

    var body: some View {
        CityMapView(
            buildings: viewModel.city.buildings,
            cityName: viewModel.city.name,
            viewModel: viewModel,
            showsDoneButton: false
        )
        .inspector(isPresented: $showingDetails) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    CityDetailView(city: city)
                    CityItineraryView(city: city)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .inspectorColumnWidth(min: 360, ideal: 420, max: 560)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation { showingDetails.toggle() }
                } label: {
                    Label("City Details", systemImage: "sidebar.trailing")
                }
                .help("Show or hide the city's details")
            }
        }
    }
}

// MARK: - Menu bar

struct StampedCommands: Commands {
    let navManager: NavigationManager
    @AppStorage("mac_shows_city_details") private var showingDetails = true

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { send(.settings) }
                .keyboardShortcut(",", modifiers: .command)
        }
        CommandGroup(after: .textEditing) {
            Button("Search Cities and Landmarks") { send(.search) }
                .keyboardShortcut("f", modifiers: .command)
        }
        CommandGroup(after: .sidebar) {
            Button(showingDetails ? "Hide City Details" : "Show City Details") {
                withAnimation { showingDetails.toggle() }
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
        }
        CommandMenu("Passport") {
            Button("My Passport") { send(.passport) }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            Button("My Journey") { send(.myJourney) }
                .keyboardShortcut("j", modifiers: [.command, .shift])
            Button("Achievements") { send(.achievements) }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            Divider()
            Button("My Trips") { send(.myTrips) }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Button("My College List") { send(.collegeList) }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Button("World Map") { send(.worldMap) }
                .keyboardShortcut("m", modifiers: [.command, .shift])
        }
    }

    private func send(_ command: MenuCommand) {
        navManager.menuCommand = command
    }
}
#endif
