//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import Foundation
import SwiftUI

// MARK: - Components
extension PassportView {
    
    var discoveryRankHeader: some View {
        Button(action: { showingProgressDetails.toggle() }) {
            HStack(spacing: 15) {
                ZStack {
                    Circle()
                        .fill(brandColor.opacity(0.1))
                        .frame(width: 50, height: 50)
                    Image(systemName: "medal.fill")
                        .foregroundColor(brandColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(discoveryRank.uppercased())
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.black)
                    Text("Official Traveler Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.caption.bold())
                    .rotationEffect(.degrees(showingProgressDetails ? 180 : 0))
            }
            .passportCard(isHighContrast: isHighContrast, brandColor: brandColor)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .hoverEffect(.highlight)
    }

    var globalProgressHeader: some View {
        let percentage = totalBuildingsInApp > 0 ? Double(totalVisitedInApp) / Double(totalBuildingsInApp) : 0
        
        return VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(brandColor.opacity(0.1), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: percentage)
                    .stroke(brandColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text("\(Int(percentage * 100))%")
                        .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 30 : 40, weight: .black, design: .rounded))
                    Text("COMPLETE")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 140, height: 140)
            
            Text("\(totalVisitedInApp) of \(totalBuildingsInApp) Landmarks Discovered")
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(brandColor.opacity(0.05))
        .cornerRadius(20)
    }

    func passportSection(for city: CityLocation.City, visitedCount: Int) -> some View {
        let total = city.buildings.count
        let isDone = visitedCount == total
        let progress = total > 0 ? Double(visitedCount) / Double(total) : 0
        
        return VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(city.name)
                        .font(.title3.bold())
                    Text("\(visitedCount) / \(total) Collected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                if isDone {
                    NavigationLink(destination: CityStampDetailView(city: city, date: "JAN 2026", namespace: stampAnimation)) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 32))
                            .foregroundColor(brandColor)
                            .matchedGeometryEffect(id: city.id, in: stampAnimation)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: visitedCount > 0 ? "hourglass" : "lock.fill")
                        .foregroundColor(.secondary.opacity(0.4))
                }
            }
            
            ProgressView(value: progress)
                .tint(isDone ? .green : brandColor)
                .scaleEffect(x: 1, y: 1.5)
        }
        .passportCard(isHighContrast: isHighContrast, brandColor: brandColor)
        .opacity(visitedCount > 0 ? 1 : 0.6) // Visual cue for unstarted cities
    }
    
    var customEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "passport")
                .font(.system(size: 80))
                .foregroundColor(.secondary.opacity(0.3))
            Text("Begin Your Journey")
                .font(.title.bold())
            Text("Visit buildings in the city guide to start collecting official stamps.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Logic
extension PassportView {
    var totalBuildingsInApp: Int { CityLocation.City.allCases.reduce(0) { $0 + $1.buildings.count } }
    var totalVisitedInApp: Int { CityLocation.City.allCases.reduce(0) { $0 + countVisited(in: $1) } }
    var isEmptyState: Bool { totalVisitedInApp == 0 }
    
    var discoveryRank: String {
        let percent = totalBuildingsInApp > 0 ? Double(totalVisitedInApp) / Double(totalBuildingsInApp) : 0
        switch percent {
        case 0..<0.1: return "Tourist"
        case 0.1..<0.4: return "Urban Explorer"
        case 0.4..<0.7: return "Architecture Critic"
        case 0.7..<0.9: return "City Historian"
        default: return "Grand Master"
        }
    }

    func countVisited(in city: CityLocation.City) -> Int {
        city.buildings.filter { UserDefaults.standard.bool(forKey: "visited_\($0.id)") }.count
    }
}

// MARK: - View Modifiers
struct PassportCardStyle: ViewModifier {
    let isHighContrast: Bool
    let brandColor: Color
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isHighContrast ? Color.primary.opacity(0.1) : Color(UIColor.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(isHighContrast ? 0 : 0.05), radius: 10, y: 4)
    }
}

extension View {
    func passportCard(isHighContrast: Bool, brandColor: Color) -> some View {
        self.modifier(PassportCardStyle(isHighContrast: isHighContrast, brandColor: brandColor))
    }
}
