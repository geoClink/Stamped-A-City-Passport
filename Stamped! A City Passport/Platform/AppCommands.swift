//
//  AppCommands.swift
//  Stamped! A City Passport
//
//  The menu bar commands and their keyboard shortcuts. On the Mac they fill the
//  menu bar; on iPad they fill the menu bar and the list that shows while holding
//  Command on a hardware keyboard. iPhone has no hardware keyboard menus.
//
//  Each window says what it can do through `focusedSceneValue`, so a command acts
//  on the frontmost window: Command-N in a trip planner starts a trip in that city,
//  Command-F searches the main window you're looking at, not every main window.
//

import SwiftUI

/// Menu bar commands, passed to the main window (CityListView.handleMenuCommand).
enum MenuCommand: Equatable {
    case search, passport, myJourney, myTrips, worldMap, achievements, collegeList, settings
    case newTrip, nextCity, previousCity
}

/// The main window's way to run a menu command, published while it's frontmost.
struct MainWindowCommands {
    let perform: (MenuCommand) -> Void
}

/// File > New Trip in whichever trip screen is frontmost (My Trips or a city's planner).
struct NewTripAction {
    let perform: () -> Void
}

extension FocusedValues {
    @Entry var mainWindowCommands: MainWindowCommands?
    @Entry var newTripAction: NewTripAction?
}

enum SupportLinks {
    /// The website's support and contact page, also the App Store Support URL
    static let help = URL(string: "https://\(WebLinkRouter.host)/contact.html")!
}

struct StampedCommands: Commands {
    /// The main window's scene id, so File > New Window can open another one
    static let mainWindowID = "main"

    let navManager: NavigationManager
    @FocusedValue(\.mainWindowCommands) private var mainWindow
    @FocusedValue(\.newTripAction) private var newTripAction
    @Environment(\.openURL) private var openURL
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    @AppStorage("mac_shows_city_details") private var showingDetails = true
    #endif

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { send(.settings) }
                .keyboardShortcut(",", modifiers: .command)
        }
        CommandGroup(replacing: .newItem) {
            Button("New Trip") {
                if let newTripAction {
                    newTripAction.perform()
                } else {
                    send(.newTrip)
                }
            }
            .keyboardShortcut("n", modifiers: .command)
            #if os(macOS)
            // Command-N is New Trip now, so a second main window moves to Option-Command-N
            Button("New Window") { openWindow(id: Self.mainWindowID) }
                .keyboardShortcut("n", modifiers: [.command, .option])
            #endif
        }
        CommandGroup(after: .textEditing) {
            Button("Search Cities and Landmarks") { send(.search) }
                .keyboardShortcut("f", modifiers: .command)
        }
        CommandGroup(after: .sidebar) {
            #if os(macOS)
            Button(showingDetails ? "Hide City Details" : "Show City Details") {
                withAnimation { showingDetails.toggle() }
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            Divider()
            #endif
            // The next and previous city in the sidebar's list, like Safari's tabs
            Button("Next City") { mainWindow?.perform(.nextCity) }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                .disabled(mainWindow == nil)
            Button("Previous City") { mainWindow?.perform(.previousCity) }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
                .disabled(mainWindow == nil)
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
        CommandGroup(replacing: .help) {
            Button("Stamped! Help") { openURL(SupportLinks.help) }
        }
    }

    /// The frontmost main window runs the command. With a panel window in front
    /// (World Map, My Trips...), it goes to the main window through NavigationManager.
    private func send(_ command: MenuCommand) {
        if let mainWindow {
            mainWindow.perform(command)
        } else {
            navManager.menuCommand = command
        }
    }
}
