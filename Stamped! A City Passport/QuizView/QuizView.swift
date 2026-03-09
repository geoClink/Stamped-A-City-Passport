//
//  SwiftUIView.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI

struct QuizView: View {
    @StateObject private var viewModel: QuizViewModel
    @Environment(\.dismiss) var dismiss
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.colorSchemeContrast) private var systemContrast
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    
    @AppStorage("high_contrast_mode") var manualHighContrast = false
    @AppStorage("reduce_motion") var manualReduceMotion = false
    
    private var isHighContrast: Bool { manualHighContrast || systemContrast == .increased }
    private var reduceMotion: Bool { manualReduceMotion || systemReduceMotion }
    private var brandColor: Color { isHighContrast ? .primary : Color.adventureOrange }
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    init(buildings: [Building], cityName: String) {
        _viewModel = StateObject(wrappedValue: QuizViewModel(buildings: buildings, cityName: cityName))
    }

    var body: some View {
        GeometryReader { proxy in
            let isPortrait = proxy.size.height > proxy.size.width
            let useSideBySide = isIPad && horizontalSizeClass == .regular && !isPortrait
            
            NavigationStack {
                ZStack {
                    backgroundLayer
                    
                    VStack(spacing: 0) {
                        if viewModel.isGameOver {
                            resultsView
                                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .scale, removal: .opacity))
                        } else if let building = viewModel.currentBuilding {
                            // Pass the live orientation state down
                            adaptiveLayout(building, useSideBySide: useSideBySide, isPortrait: isPortrait)
                        }
                    }
                    
                    if viewModel.showingStreakCelebration {
                        streakCelebrationOverlay.zIndex(1)
                    }
                }
                .navigationTitle("\(viewModel.cityName) Expert")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Exit") { dismiss() }
                            .fontWeight(isHighContrast ? .black : .bold)
                            .foregroundColor(brandColor)
                    }
                }
            }
        }
    }
}

// MARK: - Layout Orchestration
private extension QuizView {
    
    @ViewBuilder
    func adaptiveLayout(_ building: Building, useSideBySide: Bool, isPortrait: Bool) -> some View {
        if useSideBySide {
            ipadLandscapeLayout(building)
        } else {
            stackedLayout(building, isPortrait: isPortrait)
        }
    }

    func stackedLayout(_ building: Building, isPortrait: Bool) -> some View {
        ScrollView {
            VStack(spacing: 32) {
                headerView(useSideBySide: false)
                
                ProgressView(value: Double(viewModel.questionCount), total: Double(viewModel.maxQuestions))
                    .tint(brandColor)
                    .scaleEffect(x: 1, y: 1.5)
                    .padding(.horizontal, isIPad ? 100 : 20)

                dossierCard(building)
                    .padding(.horizontal, isIPad ? 100 : 20)
                
                voiceControlSection(useSideBySide: false)
                    .padding(.horizontal, isIPad ? 100 : 20)
                
                interactionArea(useSideBySide: false, isPortrait: isPortrait)
                    .padding(.horizontal, isIPad ? 100 : 0)
                
                
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
    }
    
    func ipadLandscapeLayout(_ building: Building) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 30) {
                headerView(useSideBySide: true)
                
                ProgressView(value: Double(viewModel.questionCount), total: Double(viewModel.maxQuestions))
                    .tint(brandColor)
                    .scaleEffect(x: 1, y: 2)
                
                dossierCard(building)
                
                Spacer()
                
                voiceControlSection(useSideBySide: true)
            }
            .padding(40)
            .frame(width: 450)
            
            ZStack {
                Color.primary.opacity(isHighContrast ? 0 : 0.03)
                    .ignoresSafeArea()
                
                interactionArea(useSideBySide: true, isPortrait: false)
                    .padding(60)
            }
        }
    }
    
    func interactionArea(useSideBySide: Bool, isPortrait: Bool) -> some View {
        VStack(spacing: 32) {
            if useSideBySide { Spacer() }
            
            VStack(spacing: 12) {
                Text("FIELD INQUIRY")
                    .font(.caption2.bold())
                    .foregroundColor(brandColor)
                    .tracking(2)
                
                Text(viewModel.currentQuestionType.prompt)
                    .font(.system(isIPad ? .title : .headline, design: .serif))
                    .fontWeight(isHighContrast ? .black : .bold)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal)

            answerButtonSection(useSideBySide: useSideBySide, isPortrait: isPortrait)
            
            hintSection
            
            if useSideBySide { Spacer() }
        }
    }
}

// MARK: - Components
private extension QuizView {
    
    var backgroundLayer: some View {
        (isHighContrast ? Color(UIColor.systemBackground) : Color(UIColor.systemGroupedBackground))
            .ignoresSafeArea()
    }

    func headerView(useSideBySide: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("LOG \(viewModel.questionCount) OF \(viewModel.maxQuestions)")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundColor(.secondary)
                Text("SCORE: \(viewModel.score)")
                    .font(.title3.bold())
                    .foregroundColor(brandColor)
            }
            Spacer()
            if viewModel.currentStreak > 1 {
                streakBadge
            }
        }
        .padding(.horizontal, (useSideBySide || !isIPad) ? 20 : 100)
    }

    var streakBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
            Text("\(viewModel.currentStreak)")
        }
        .font(.headline.bold()).foregroundColor(.white)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(
            LinearGradient(colors: [brandColor, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(Capsule())
    }

    @ViewBuilder
    func answerButtonSection(useSideBySide: Bool, isPortrait: Bool) -> some View {
        Group {
            if isIPad && !isPortrait {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)], spacing: 16) {
                    buttonsContent
                }
            } else {
                VStack(spacing: 16) {
                    buttonsContent
                }
            }
        }
        .padding(.horizontal, (useSideBySide || !isIPad) ? 20 : 100)
    }

    @ViewBuilder
    var buttonsContent: some View {
        ForEach(viewModel.options, id: \.self) { option in
            Button {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.processAnswer(option, reduceMotion: reduceMotion)
                }
            } label: {
                HStack(spacing: 12) {
                    Text(option)
                        .font(.system(isIPad ? .title3 : .body, design: .rounded))
                        .fontWeight(isHighContrast ? .black : .bold)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    
                    Spacer()
                    
                    selectionIcon(for: option)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .frame(height: isIPad ? 80 : 70)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(buttonBackgroundColor(for: option))
                )
                .foregroundColor(buttonForegroundColor(for: option))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isHighContrast ? Color.primary : Color.primary.opacity(0.1), lineWidth: 1)
                )
            }
            .disabled(viewModel.selectedOption != nil || viewModel.showingStreakCelebration)
        }
    }

    func selectionIcon(for option: String) -> some View {
        Group {
            if let selected = viewModel.selectedOption {
                if option == viewModel.getCorrectAnswer() {
                    Image(systemName: "checkmark.circle.fill")
                } else if selected == option {
                    Image(systemName: "xmark.circle.fill")
                } else {
                    Image(systemName: "circle")
                }
            } else {
                Image(systemName: "circle")
            }
        }
        .font(.title3)
    }

    func buttonBackgroundColor(for option: String) -> Color {
        if let selected = viewModel.selectedOption {
            if option == viewModel.getCorrectAnswer() { return .green }
            if selected == option { return .red }
            
            return isHighContrast ? Color(UIColor.systemBackground) : Color(UIColor.secondarySystemGroupedBackground).opacity(0.5)
        }
        
        return isHighContrast ? Color(UIColor.systemBackground) : Color(UIColor.secondarySystemGroupedBackground)
    }
    
    func buttonForegroundColor(for option: String) -> Color {
        if let selected = viewModel.selectedOption {
            if option == viewModel.getCorrectAnswer() || selected == option {
                return .white
            }
        }
        return .primary
    }

    func dossierCard(_ building: Building) -> some View {
        VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label("FIELD DATA", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(brandColor)
                    Spacer()
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .opacity(viewModel.selectedOption == nil ? 1.0 : 0.3)
                }
                
                Text(viewModel.currentQuestionType == .name ? "IDENTIFICATION REQUIRED" : building.name.uppercased())
                    .font(.system(isIPad ? .title2 : .headline, design: .serif).bold())
                    .foregroundColor(viewModel.currentQuestionType == .name ? .secondary : .primary)
                    .italic(viewModel.currentQuestionType == .name)
                
                Divider().background(brandColor.opacity(0.3))
                
                VStack(alignment: .leading, spacing: 14) {
                    dossierRow(label: "STYLE", value: building.buildingStyle, icon: "fossil.shell", hide: viewModel.currentQuestionType == .style)
                    dossierRow(label: "YEAR", value: "\(building.yearBuilt)", icon: "calendar", hide: viewModel.currentQuestionType == .year)
                    dossierRow(label: "STORIES", value: "\(building.numberOfStories) Stories", icon: "building.2", hide: viewModel.currentQuestionType == .stories)
                    dossierRow(label: "ARCHITECT", value: building.architect, icon: "person.text.rectangle", hide: viewModel.currentQuestionType == .architect)
                }
            }
        .padding(isIPad ? 32 : 24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(isHighContrast ? Color(UIColor.systemBackground) : Color(UIColor.secondarySystemGroupedBackground))
        )
        .shadow(color: Color.black.opacity(isHighContrast ? 0 : 0.05), radius: 15, y: 5)
    }

    func dossierRow(label: String, value: String, icon: String, hide: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.footnote)
                .frame(width: 24, height: 24)
                .background(brandColor.opacity(0.15))
                .foregroundColor(brandColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 10, weight: .black)).foregroundColor(.secondary)
                Text(hide ? "CLASSIFIED" : value)
                    .font(.system(isIPad ? .headline : .subheadline, design: .rounded).bold())
                    .foregroundColor(hide ? brandColor.opacity(0.6) : .primary)
            }
        }
    }

    var resultsView: some View {
        VStack(spacing: 40) {
            Spacer()
            ZStack {
                Circle().stroke(brandColor.opacity(0.2), lineWidth: 20).frame(width: 200, height: 200)
                Image(systemName: viewModel.score == 10 ? "checkmark.seal.fill" : "medal.fill")
                    .font(.system(size: 100))
                    .foregroundColor(brandColor)
            }
            Text("\(viewModel.score) / \(viewModel.maxQuestions)")
                .font(.system(size: 80, weight: .black, design: .rounded))
                .foregroundColor(brandColor)
            
            Button { dismiss() } label: {
                Text("RETURN TO CITY")
                    .font(.headline).frame(maxWidth: 300).padding(.vertical, 20)
                    .background(brandColor).foregroundColor(.white).clipShape(Capsule())
            }
            Spacer()
        }
    }

    var hintSection: some View {
        VStack(spacing: 16) {
            Button(action: { withAnimation { viewModel.showHint.toggle() } }) {
                Label(viewModel.showHint ? "Conceal Hint" : "Request Hint", systemImage: "lightbulb.fill")
                    .font(.caption.bold())
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Capsule().stroke(viewModel.showHint ? brandColor : Color.secondary.opacity(0.3)))
            }
            .foregroundColor(viewModel.showHint ? brandColor : .secondary)
            
            if viewModel.showHint {
                Text(viewModel.getHintText())
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(brandColor.opacity(0.15)))
                    .padding(.horizontal, isIPad ? 100 : 20)
            }
        }
    }

    func voiceControlSection(useSideBySide: Bool) -> some View {
        VStack(spacing: 8) {
            Button(action: {
                if viewModel.isListening { viewModel.stopVoiceInput() }
                else { viewModel.startVoiceInput(reduceMotion: reduceMotion) }
            }) {
                HStack {
                    Image(systemName: viewModel.isListening ? "waveform" : "mic.fill")
                        .font(.system(size: 18, weight: .bold))
                    
                    Text(viewModel.isListening ? "LISTENING..." : "ANSWER VIA VOICE")
                        .font(.system(.caption, design: .monospaced).bold())
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(viewModel.isListening ? Color.red.opacity(0.1) : Color.clear)
                .foregroundColor(viewModel.isListening ? .red : brandColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(viewModel.isListening ? Color.red : brandColor, lineWidth: 2)
                )
            }
            
            if viewModel.isListening {
                Text("Speak the name of the building style or architect...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, useSideBySide ? 0 : (isIPad ? 100 : 20))
    }
    
    var streakCelebrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 30) {
                Image(systemName: "flame.fill").font(.system(size: 120))
                    .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
                Text("\(viewModel.streakMilestone) IN A ROW").font(.system(size: 44, weight: .black)).foregroundColor(.white)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { viewModel.showingStreakCelebration = false }
            }
        }
    }
}
