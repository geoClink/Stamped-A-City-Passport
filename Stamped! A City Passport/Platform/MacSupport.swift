//
//  MacSupport.swift
//  Stamped! A City Passport
//
//  The Mac-only pieces of the app: the city workspace (3D map + details
//  inspector), the panel windows (World Map, My Journey, trips, quiz...) and
//  window ids. iPhone and iPad never use these. (The menu bar is in AppCommands.swift.)
//

import SwiftUI

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
                    // The itinerary is in the city page's Plan tab
                    CityDetailView(city: city)
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

// MARK: - Panel windows

/// The ids of the Mac's extra windows, for `openWindow(id:)`.
enum MacWindowID {
    static let worldMap = "world-map"
    static let myJourney = "my-journey"
    static let achievements = "achievements"
    static let collegeList = "college-list"
    static let myTrips = "my-trips"
    static let tripPlanner = "trip-planner"
    static let quiz = "quiz"
}

/// Which trip a My Trips window opens on. nil just shows the list.
/// Opening the same value again brings that window forward instead of making a second one.
struct MyTripsWindowValue: Codable, Hashable {
    var tripID: String? = nil
}

/// A city's trip planner window, optionally opened on one trip (Campus Visit).
struct TripPlannerWindowValue: Codable, Hashable {
    let city: CityLocation.City
    var tripID: String? = nil
}

/// On iPhone and iPad these screens are sheets. A sheet on a big Mac screen looks like
/// an iPad app, so on the Mac each one gets its own resizable window instead.
/// `Window` is a single window (opening it again brings it forward); `WindowGroup(for:)`
/// makes one window per value, e.g. one quiz window per city.
struct MacPanelWindows: Scene {
    let navManager: NavigationManager

    var body: some Scene {
        Window("World Map", id: MacWindowID.worldMap) {
            WorldMapView()
                .frame(minWidth: 720, minHeight: 500)
                .macPanelWindow(navManager)
        }
        .defaultSize(width: 1280, height: 820)

        Window("My Journey", id: MacWindowID.myJourney) {
            MyJourneyView()
                .frame(minWidth: 640, minHeight: 500)
                .macPanelWindow(navManager)
        }
        .defaultSize(width: 860, height: 820)

        Window("Achievements", id: MacWindowID.achievements) {
            AchievementsView()
                .frame(minWidth: 520, minHeight: 500)
                .macPanelWindow(navManager)
        }
        .defaultSize(width: 1000, height: 820)

        Window("My College List", id: MacWindowID.collegeList) {
            CollegeListWindowContent()
                .frame(minWidth: 460, minHeight: 420)
                .macPanelWindow(navManager)
        }
        .defaultSize(width: 640, height: 720)

        WindowGroup("My Trips", id: MacWindowID.myTrips, for: MyTripsWindowValue.self) { value in
            MyTripsView(initialTripID: value.wrappedValue?.tripID)
                .frame(minWidth: 820, minHeight: 560)
                .macPanelWindow(navManager)
        }
        .defaultSize(width: 1180, height: 800)

        WindowGroup("Plan a Trip", id: MacWindowID.tripPlanner, for: TripPlannerWindowValue.self) { value in
            if let request = value.wrappedValue {
                TripPlannerWindowContent(request: request)
                    .frame(minWidth: 820, minHeight: 560)
                    .macPanelWindow(navManager)
            }
        }
        .defaultSize(width: 1180, height: 800)

        WindowGroup("Architecture Quiz", id: MacWindowID.quiz, for: CityLocation.City.self) { value in
            if let city = value.wrappedValue {
                QuizView(buildings: city.buildings, cityName: city.name)
                    // The side-by-side layout needs this much room, or the answer buttons collapse
                    .frame(minWidth: 960, minHeight: 680)
                    .macPanelWindow(navManager)
            }
        }
        .defaultSize(width: 1120, height: 800)
        // A quiz is a one-off game, so don't reopen it the next time the app launches
        .restorationBehavior(.disabled)
    }
}

private extension View {
    /// The setup every panel window shares with the main window.
    func macPanelWindow(_ navManager: NavigationManager) -> some View {
        self
            .environmentObject(navManager)
            // A Mac window is wide, so maps opened from inside (a trip's 3D tour) open the iPad way
            .environment(\.isWideWindow, true)
            // Same reason as the main window: the app's buttons draw their own shapes
            .buttonStyle(.borderless)
    }
}

/// My College List in its own window. Picking a school shows its campus in the main
/// window, like choosing it in the sidebar, and closes the list (as on iPhone).
private struct CollegeListWindowContent: View {
    @EnvironmentObject private var navManager: NavigationManager
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        CollegeListView(onOpenCampus: { campus in
            navManager.spotlightCity = campus
            dismissWindow(id: MacWindowID.collegeList)
        })
    }
}

/// A city's trip planner in its own window. On iPhone the city page passes its view model
/// in; a separate window has no city page, so it makes and keeps its own (like My Trips does).
private struct TripPlannerWindowContent: View {
    let request: TripPlannerWindowValue
    @StateObject private var viewModel: CityDetailViewModel

    init(request: TripPlannerWindowValue) {
        self.request = request
        _viewModel = StateObject(wrappedValue: CityDetailViewModel(city: request.city))
    }

    var body: some View {
        TripPlannerView(viewModel: viewModel, initialTripID: request.tripID)
    }
}

extension View {
    /// Mac: when `isPresented` turns true, opens the window with this id (instead of a sheet).
    func opensWindow(id: String, when isPresented: Binding<Bool>) -> some View {
        modifier(OpenWindowWhenTrue(isPresented: isPresented) { openWindow in
            openWindow(id: id)
        })
    }

    /// Mac: when `isPresented` turns true, opens the window for this value (instead of a sheet).
    func opensWindow<Value: Codable & Hashable>(id: String, value: Value, when isPresented: Binding<Bool>) -> some View {
        modifier(OpenWindowWhenTrue(isPresented: isPresented) { openWindow in
            openWindow(id: id, value: value)
        })
    }
}

/// Lets the existing `showingX = true` buttons and menu commands open a window on the Mac.
private struct OpenWindowWhenTrue: ViewModifier {
    @Binding var isPresented: Bool
    let open: (OpenWindowAction) -> Void
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onChange(of: isPresented) { _, isOn in
            guard isOn else { return }
            open(openWindow)
            // Back to false, so the next click opens the window again (or brings it forward)
            isPresented = false
        }
    }
}

#endif
