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
            HStack(spacing: DS.Space.m) {
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
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text("Official Traveler Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer(minLength: DS.Space.s)
                
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
        
        return VStack(spacing: DS.Space.xl) {
            ZStack {
                Circle()
                    .stroke(brandColor.opacity(0.1), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: percentage)
                    .stroke(brandColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text("\(Int(percentage * 100))%")
                        .font(.system(.largeTitle, design: .rounded).weight(.black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("COMPLETE")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 140, height: 140)
            
            Text("\(totalVisitedInApp) of \(totalBuildingsInApp) Landmarks Discovered")
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Space.section)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(brandColor.opacity(0.05))
        )
    }

    func passportSection(for city: CityLocation.City, visitedCount: Int) -> some View {
        let total = city.buildings.count
        let isDone = visitedCount == total
        let progress = total > 0 ? Double(visitedCount) / Double(total) : 0
        
        return VStack(alignment: .leading, spacing: DS.Space.m) {
            HStack {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text(city.name)
                        .font(.system(.title3, design: .serif).bold())
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text("\(visitedCount) / \(total) Collected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                if isDone {
                    NavigationLink(destination: CityStampDetailView(city: city, date: UserDefaults.standard.string(forKey: "date_completed_\(city.name)") ?? "", namespace: stampAnimation)) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.largeTitle)
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
        VStack(spacing: DS.Space.xl) {
            Image(systemName: "passport")
                .font(.system(size: emptyIconSize))
                .foregroundColor(.secondary.opacity(0.3))
            Text("Begin Your Journey")
                .font(.title.bold())
            Text("Visit buildings in the city guide to start collecting official stamps.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, DS.Space.section)
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
        city.buildings.filter { GlobalProgressManager.shared.visitedIDs.contains($0.id) }.count
    }
}

// MARK: - View Modifiers
struct PassportCardStyle: ViewModifier {
    let isHighContrast: Bool
    let brandColor: Color
    
    func body(content: Content) -> some View {
        content
            .padding(DS.Space.l)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(isHighContrast ? Color.primary.opacity(0.1) : DS.Palette.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
            )
    }
}

extension View {
    func passportCard(isHighContrast: Bool, brandColor: Color) -> some View {
        self.modifier(PassportCardStyle(isHighContrast: isHighContrast, brandColor: brandColor))
    }
}
