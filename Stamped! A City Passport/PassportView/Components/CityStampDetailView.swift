//
//  SwiftUIView.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI

struct CityStampDetailView: View {
    let city: CityLocation.City
    let date: String
    var namespace: Namespace.ID
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var sizeClass
    @AppStorage("reduce_motion") var manualReduceMotion = false
    
    @State private var stampScale: CGFloat = 0.5
    @State private var stampOpacity: Double = 0
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            passportBackgroundPattern
            
            VStack(spacing: sizeClass == .regular ? 50 : 30) {
                Spacer()
                
                VStack(spacing: 20) {
                    PassportStampView(
                        cityName: city.name,
                        dateCompleted: date,
                        funFact: "Master of \(city.name) Architecture"
                    )
                    .matchedGeometryEffect(id: manualReduceMotion ? nil : city.id, in: namespace)
                    .scaleEffect(stampScale)
                    .opacity(stampOpacity)
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                    
                    if sizeClass == .regular {
                        // Extra detail for iPad users
                        Text("This document certifies that the traveler has successfully discovered and documented all primary architectural landmarks in \(city.name).")
                            .font(.system(.body, design: .serif))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: 400)
                            .padding(.top)
                    }
                }
                
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        ShareLink(item: "I just unlocked the \(city.name) Architecture Stamp! 🏛️") {
                            Label("Share Achievement", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { dismiss() }) {
                            Text("Dismiss")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 40)
                                .background(Color.adventureOrange)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text("VERIFIED ON \(date.uppercased())")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .foregroundColor(.secondary.opacity(0.6))
                }
                
                Spacer()
            }
            .padding(40)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
                stampScale = 1.0
                stampOpacity = 1.0
            }
        }
    }
    
    var passportBackgroundPattern: some View {
        VStack(spacing: 40) {
            ForEach(0..<10) { _ in
                Divider()
                    .overlay(Color.secondary.opacity(0.1))
                    .padding(.horizontal, 20)
            }
        }
        .allowsHitTesting(false)
    }
}
