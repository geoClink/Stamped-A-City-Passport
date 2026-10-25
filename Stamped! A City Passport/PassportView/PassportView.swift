//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI
import Combine

// MARK: - Main Passport View
struct PassportView: View {
    @Namespace var stampAnimation
    @StateObject var progressManager = GlobalProgressManager.shared

    let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 500), spacing: DS.Space.l)
    ]
    
    @State var showingProgressDetails = false
    
    @Environment(\.colorSchemeContrast) var systemContrast
    @Environment(\.accessibilityReduceMotion) var systemReduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @AppStorage("high_contrast_mode") var manualHighContrast = false
    @AppStorage("reduce_motion") var manualReduceMotion = false
    @ScaledMetric(relativeTo: .largeTitle) var emptyIconSize: CGFloat = 80
    
    var isHighContrast: Bool { manualHighContrast || systemContrast == .increased }
    var reduceMotion: Bool { manualReduceMotion || systemReduceMotion }
    var brandColor: Color { isHighContrast ? .primary : DS.Palette.accent }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DS.Palette.pageBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DS.Space.xl) {
                        VStack(spacing: DS.Space.l) {
                            discoveryRankHeader
                            
                            if showingProgressDetails {
                                globalProgressHeader
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        .dsPageMargin()
                        
                        LazyVGrid(columns: columns, spacing: DS.Space.l) {
                            ForEach(CityLocation.City.allCases) { city in
                                let visitedCount = countVisited(in: city)
                                passportSection(for: city, visitedCount: visitedCount)
                            }
                        }
                        .dsPageMargin()
                    }
                    .padding(.vertical, DS.Space.l)
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
