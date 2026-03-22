//
//  CityDetailView.swift
//  Stamped
//
//  Created by George Clinkscales on 2/1/26.
//

import SwiftUI

struct CityDetailView: View {
    // MARK: - State & Settings
    @StateObject var viewModel: CityDetailViewModel
    @ObservedObject var soundManager = SoundManager.shared
    
    @Environment(\.colorSchemeContrast) var systemContrast
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var sizeClass
    
    @AppStorage("high_contrast_mode") var appHighContrast = false
    @AppStorage("reduce_motion") var reduceMotion = false
    @AppStorage var highScore: Int
    
    @State private var showingQuiz = false
    @State private var showingFinalConfirmation = false
    @State private var showingCelebration = false
    @State private var resetType: CityDetailViewModel.ResetType = .none
    
    var isHighContrast: Bool { systemContrast == .increased || appHighContrast }
    var brandColor: Color { isHighContrast ? .primary : Color.adventureOrange }
    
    init(city: CityLocation.City) {
        _viewModel = StateObject(wrappedValue: CityDetailViewModel(city: city))
        self._highScore = AppStorage(wrappedValue: 0, "high_score_\(city.name)")
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: isHighContrast ? 32 : 24) {
                CityHeroHeader(
                    city: viewModel.city,
                    progress: viewModel.progress,
                    isHighContrast: isHighContrast,
                    masteryTier: viewModel.getMastery(isHighContrast: isHighContrast).tier
                )
                
                QuizInteractionCard(
                    highScore: highScore,
                    isHighContrast: isHighContrast,
                    onTap: {
                        HapticManager.shared.trigger(.selection)
                        showingQuiz = true
                    }
                )
                .padding(.horizontal)
                .hoverEffect(.lift)
                
                if viewModel.isCompleted {
                    PassportStampView(
                        cityName: viewModel.city.name,
                        dateCompleted: viewModel.completionDate,
                        funFact: viewModel.city.details.funFact,
                        isHighContrast: isHighContrast
                    )
                    .padding(.horizontal)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                }
                
                Divider()

                
                LandmarkSection(viewModel: viewModel, isHighContrast: isHighContrast)
                
                Divider()
                
                TravelInfoSection(viewModel: viewModel, isHighContrast: isHighContrast)
                
            }
            .padding(.bottom)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .background(isHighContrast ? Color(UIColor.systemBackground) : Color(UIColor.systemGroupedBackground))
        .onChange(of: viewModel.isCompleted) { newValue, _ in
            if newValue {
                HapticManager.shared.trigger(.success)
                SoundManager.shared.playStampSound()
                viewModel.handleCompletion()
                showingCelebration = true
            }
        }
        .onReceive(viewModel.$didJustComplete) { justCompleted in
            if justCompleted {
                // One-shot presentation for the celebration overlay
                HapticManager.shared.trigger(.success)
                SoundManager.shared.playStampSound()
                showingCelebration = true
                // Reset the flag so it can fire again for future completions
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    viewModel.didJustComplete = false
                }
            }
        }
        .fullScreenCover(isPresented: $showingCelebration) {
            celebrationCover
        }
        .fullScreenCover(isPresented: $showingQuiz) {
            NavigationStack {
                QuizView(buildings: viewModel.city.buildings, cityName: viewModel.city.name)
            }
        }
        .alert("Confirm Reset", isPresented: $showingFinalConfirmation) {
            Button("Yes, Reset", role: .destructive) { executeResetAction() }
            Button("Cancel", role: .cancel) { resetType = .none }
        } message: {
            Text(viewModel.getConfirmationMessage(for: resetType))
        }
    }
    
    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Section("Reset Progress") {
                    Button(role: .destructive) { promptReset(.quiz) } label: { Label("Reset Quiz Score", systemImage: "arrow.counterclockwise") }
                    Button(role: .destructive) { promptReset(.passport) } label: { Label("Reset Stamps", systemImage: "person.badge.minus") }
                    Button(role: .destructive) { promptReset(.photos) } label: { Label("Reset Photos", systemImage: "photo.on.rectangle.angled") }
                    Button(role: .destructive) { promptReset(.everything) } label: { Label("Reset Everything", systemImage: "trash") }
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 22))
                    .fontWeight(isHighContrast ? .black : .regular)
                    .foregroundColor(brandColor)
                    .contentShape(Circle())
            }
        }
    }
    
    // MARK: - Helpers
    private func promptReset(_ type: CityDetailViewModel.ResetType) {
        self.resetType = type
        self.showingFinalConfirmation = true
    }
    
    private func executeResetAction() {
        viewModel.resetProgress(for: resetType)
        if resetType == .everything || resetType == .quiz {
            highScore = 0
        }
        resetType = .none
    }
}
