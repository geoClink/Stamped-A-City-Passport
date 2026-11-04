//
//  NavigationManager.swift
//  Stamped! A City Passport
//
//  Created by George Clinkscales on 1/27/26.
//

import Foundation
import SwiftUI
import Combine

class NavigationManager: ObservableObject {
    /// The app's one navigation state, so Siri and Shortcuts actions (StampedShortcuts.swift) can reach it
    static let shared = NavigationManager()

    @Published var selectedTab: Int = 0
    @Published var spotlightCity: CityLocation.City? = nil
    /// Mac menu bar command waiting for the main window to act on it
    @Published var menuCommand: MenuCommand? = nil
    /// Set by the "Open My Passport" Siri / Shortcuts action
    @Published var passportRequested = false
    /// Set by File > New Trip in the main window; My Trips opens and asks where the trip is
    @Published var newTripRequested = false
}
