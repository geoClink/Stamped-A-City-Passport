//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI
import Combine

// MARK: - Navigation Manager
class NavigationManager: ObservableObject {
    @Published var selectedTab: Int = 0
}


// MARK: - Main Passport View
struct PassportView: View {
    @Namespace var stampAnimation
    @StateObject var progressManager = GlobalProgressManager.shared
    @EnvironmentObject var navManager: NavigationManager
    
    let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 500), spacing: 20)
    ]
    
    @State var showingProgressDetails = false
    
    @Environment(\.colorSchemeContrast) var systemContrast
    @Environment(\.accessibilityReduceMotion) var systemReduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @AppStorage("high_contrast_mode") var manualHighContrast = false
    @AppStorage("reduce_motion") var manualReduceMotion = false
    
    var isHighContrast: Bool { manualHighContrast || systemContrast == .increased }
    var reduceMotion: Bool { manualReduceMotion || systemReduceMotion }
    var brandColor: Color { isHighContrast ? .primary : .orange }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            discoveryRankHeader
                            
                            if showingProgressDetails {
                                globalProgressHeader
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal)
                        
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(CityLocation.City.allCases) { city in
                                let visitedCount = countVisited(in: city)
                                passportSection(for: city, visitedCount: visitedCount)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .opacity(isEmptyState ? 0 : 1)
                
                if isEmptyState {
                    customEmptyState
                }
            }
            .navigationTitle("Your Passport")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        HapticManager.shared.trigger(.selection) // Add this
                        withAnimation(.spring()) { showingProgressDetails.toggle() }
                    } label: {
                        Label("Stats", systemImage: showingProgressDetails ? "chart.pie.fill" : "chart.pie")
                    }
                }
            }
        }
    }
}
