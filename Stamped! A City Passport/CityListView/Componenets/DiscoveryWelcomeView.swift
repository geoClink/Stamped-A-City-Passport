//
//  SwiftUIView.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//
import SwiftUI

struct DiscoveryWelcomeView: View {
    @Environment(\.colorSchemeContrast) var systemContrast
    @AppStorage("high_contrast_mode") var manualHighContrast = false
    
    var isHighContrast: Bool {
        manualHighContrast || systemContrast == .increased
    }

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(isHighContrast ? Color.clear : Color.adventureOrange.opacity(0.1))
                    .frame(width: 140, height: 140)
                
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(isHighContrast ? .primary : Color.adventureOrange)
            }
            
            VStack(spacing: 12) {
                Text("Ready to Explore?")
                    .font(.system(.title, design: .rounded).bold())
                
                Text("Select a destination from the sidebar to begin your architectural journey and earn your first stamp.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)
            }
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                Label("Swipe from the left if the sidebar is hidden", systemImage: "arrow.left.to.line")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
}
