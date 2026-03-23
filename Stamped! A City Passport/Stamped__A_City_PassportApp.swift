//
//  Stamped__A_City_PassportApp.swift
//  Stamped! A City Passport
//
//  Created by George Clinkscales on 2/25/26.
//

import SwiftUI
import Foundation


// MARK: - ORIENTATION MANAGER
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .landscape
        } else {
            return .portrait
        }
    }
}

@main
struct GlobalDiscoveryApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @StateObject private var progressManager = GlobalProgressManager.shared
    @StateObject private var navManager = NavigationManager()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasSeenOnboarding {
                    CityListView()
                        .environmentObject(progressManager)
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
                // Attempt to refresh the remote registry if configured in Info.plist
                await BuildingRegistryUpdater.refreshIfNeeded()
            }
        }
    }
}
