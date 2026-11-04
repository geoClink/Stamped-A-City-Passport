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
    /// Set by "Open a Landmark" and "What's Near Me": the landmark's page opens once its city is on screen
    @Published var landmarkRequest: LandmarkRequest? = nil
    /// Set by "Start a Walking Tour": the city's map opens and its Tour starts
    @Published var tourRequestCity: CityLocation.City? = nil
}

/// A landmark page a Siri or Shortcuts action wants open
struct LandmarkRequest: Equatable {
    let city: CityLocation.City
    let buildingID: String
}
