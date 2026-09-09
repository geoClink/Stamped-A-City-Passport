//
//  NavigationManager.swift
//  Stamped! A City Passport
//
//  Created by George Clinkscales on 1/27/26.
//

import Foundation
import SwiftUI

class NavigationManager: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var spotlightCity: CityLocation.City? = nil
}
