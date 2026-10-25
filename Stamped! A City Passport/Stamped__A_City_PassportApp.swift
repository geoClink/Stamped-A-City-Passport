//
//  Stamped__A_City_PassportApp.swift
//  Stamped! A City Passport
//
//  Created by George Clinkscales on 2/25/26.
//

import SwiftUI
import Foundation
import CoreSpotlight


// MARK: - ORIENTATION MANAGER
#if os(iOS)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .landscape
        } else {
            return .portrait
        }
    }
}
#endif

@main
struct GlobalDiscoveryApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @StateObject private var navManager = NavigationManager()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasSeenOnboarding {
                    CityListView()
                        .environmentObject(navManager)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else {
                    OnboardingView()
                        .environmentObject(navManager)
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.7, dampingFraction: 0.85), value: hasSeenOnboarding)
            .task {
                ProximityManager.shared.requestPermissions()
                SpotlightManager.indexAll(cities: CityLocation.City.allCases)
            }
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                if let city = SpotlightManager.city(from: activity) {
                    navManager.spotlightCity = city
                }
            }
            #if os(macOS)
            .frame(minWidth: 960, minHeight: 640)
            #endif
        }
        #if os(macOS)
        .defaultSize(width: 1440, height: 900)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            InspectorCommands()
            StampedCommands(navManager: navManager)
        }
        #endif
    }
}
