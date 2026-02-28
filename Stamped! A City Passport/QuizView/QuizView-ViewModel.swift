//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI
import AVFoundation
import Combine

@MainActor
class QuizViewModel: ObservableObject {
    // MARK: - Published State
    @Published var currentBuilding: Building?
    @Published var currentQuestionType: QuestionType = .name
    @Published var options: [String] = []
    @Published var score = 0
    @Published var currentStreak = 0
    @Published var questionCount = 0
    @Published var isGameOver = false
    @Published var selectedOption: String? = nil
    @Published var showHint = false
    @Published var showingStreakCelebration = false
    @Published var streakMilestone = 0
    @Published var shakeTrigger: CGFloat = 0
    
    @Published var isListening = false
    private let speechManager = SpeechManager()
    @Published var transcribedText: String = ""

    // MARK: - Properties
    let buildings: [Building]
    let cityName: String
    let maxQuestions = 10
    
    @AppStorage("is_sound_enabled") var isSoundEnabled = true

    // MARK: - Init
    init(buildings: [Building], cityName: String) {
        self.buildings = buildings
        self.cityName = cityName
        generateQuestion()
    }
    
    // MARK: - Voice Input Logic
    func startVoiceInput(reduceMotion: Bool) {
        isListening = true
        transcribedText = "Listening..."
        
        speechManager.startRecording { [weak self] text in
            Task { @MainActor in
                guard let self = self else { return }
                self.transcribedText = text
                let spoken = text.lowercased()
                
                for option in self.options {
                    let cleanOption = option.lowercased()
                    var isMatch = spoken.contains(cleanOption)
                    
                    if let digit = Int(cleanOption.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                        let wordVersion = self.numberToWord(digit)
                        if spoken.contains(wordVersion) {
                            isMatch = true
                        }
                    }

                    if isMatch {
                        self.stopVoiceInput()
                        self.processAnswer(option, reduceMotion: reduceMotion)
                        break
                    }
                }
            }
        }
    }

    private func numberToWord(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        return formatter.string(from: NSNumber(value: number)) ?? ""
    }

    func stopVoiceInput() {
        speechManager.stopRecording()
        isListening = false
    }
    
    // MARK: - Persistence
    var highScore: Int {
        get { UserDefaults.standard.integer(forKey: "high_score_\(cityName)") }
        set { UserDefaults.standard.set(newValue, forKey: "high_score_\(cityName)") }
    }
    
    var bestStreak: Int {
        get { UserDefaults.standard.integer(forKey: "best_streak_\(cityName)") }
        set { UserDefaults.standard.set(newValue, forKey: "best_streak_\(cityName)") }
    }
    
    var hasPerfectScore: Bool {
        get { UserDefaults.standard.bool(forKey: "perfect_\(cityName)") }
        set { UserDefaults.standard.set(newValue, forKey: "perfect_\(cityName)") }
    }

    // MARK: - Quiz Logic
    func generateQuestion() {
        showHint = false
        if questionCount >= maxQuestions {
            isGameOver = true
            return
        }
        currentBuilding = buildings.randomElement()
        currentQuestionType = QuestionType.allCases.randomElement() ?? .name
        questionCount += 1
        setupOptions()
    }

    func setupOptions() {
        let correct = getCorrectAnswer()
        let allDistractors = buildings
            .map { b in
                switch currentQuestionType {
                case .name: return b.name
                case .architect: return b.architect
                case .year: return "\(b.yearBuilt)"
                case .style: return b.buildingStyle
                case .stories: return "\(b.numberOfStories) floors"
                }
            }
            .filter { $0 != correct }
        
        let distractors = Array(Set(allDistractors)).shuffled().prefix(3)
        var newOptions = Array(distractors)
        newOptions.append(correct)
        options = newOptions.shuffled()
    }

    func getCorrectAnswer() -> String {
        guard let b = currentBuilding else { return "" }
        switch currentQuestionType {
        case .name: return b.name
        case .architect: return b.architect
        case .year: return "\(b.yearBuilt)"
        case .style: return b.buildingStyle
        case .stories: return "\(b.numberOfStories) floors"
        }
    }

    func processAnswer(_ selected: String, reduceMotion: Bool) {
        selectedOption = selected
        let isCorrect = (selected == getCorrectAnswer())
        
        UIAccessibility.post(notification: .announcement, argument: isCorrect ? "Correct!" : "Incorrect. The answer was \(getCorrectAnswer()).")
        
        if isCorrect {
            score += 1
            currentStreak += 1
            if currentStreak > bestStreak { bestStreak = currentStreak }
            if score > highScore { highScore = score }
            if score == 10 { hasPerfectScore = true }
            
            HapticManager.shared.trigger(.success)
            playSound(named: 1057)
            
            if currentStreak == 5 || currentStreak == 10 {
                streakMilestone = currentStreak
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(reduceMotion ? .none : .spring()) {
                        self.showingStreakCelebration = true
                    }
                }
            }
        } else {
            currentStreak = 0
            
            HapticManager.shared.trigger(.error)
            
            if !reduceMotion {
                withAnimation(.default) { shakeTrigger += 1 }
            }
        }
        
        let waitTime = (currentStreak == 5 || currentStreak == 10) ? 2.5 : (reduceMotion ? 0.4 : 0.8)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + waitTime) {
            withAnimation(reduceMotion ? .none : .easeInOut) {
                self.selectedOption = nil
                self.generateQuestion()
            }
        }
    }

    func getHintText() -> String {
        guard let b = currentBuilding else { return "" }
        
        switch currentQuestionType {
        case .name:
            return "This landmark is located in the heart of \(cityName) and is a prime example of \(b.buildingStyle) design."
        case .architect:
            return "The architect of this building is also famous for their work during the \(b.yearBuilt / 10 * 10)s."
        case .year:
            let era = b.yearBuilt < 1945 ? "pre-war" : "modernist"
            return "This was a major \(era) project designed by \(b.architect)."
        case .style:
            return "Look at the year \(b.yearBuilt); this style was the dominant architectural movement of that era."
        case .stories:
            return "Despite its \(b.buildingStyle) appearance, this building was quite tall for the \(b.yearBuilt / 10 * 10)s."
        }
    }

    // MARK: - Audio Logic
    func playSound(named id: SystemSoundID) {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(id)
    }
}
