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
    @Published var brokeHighScore = false
    /// A `.name` question that shows the building's photo instead of its data
    @Published var isPhotoQuestion = false
    /// Every wrong answer this round, for "Review your misses" at the end
    @Published var misses: [QuizMiss] = []

    @Published var isListening = false
    private let speechManager = SpeechManager()
    @Published var transcribedText: String = ""

    // MARK: - Properties
    let buildings: [Building]
    let cityName: String
    let maxQuestions = 10
    private var buildingQueue: [Building] = []
    /// IDs of buildings Wikipedia has a photo for. Only these get photo questions.
    private var buildingsWithPhotos: Set<String> = []
    private var generator = SystemRandomNumberGenerator()

    @AppStorage("is_sound_enabled") var isSoundEnabled = true

    // MARK: - Init
    init(buildings: [Building], cityName: String) {
        self.buildings = buildings
        self.cityName = cityName
        generateQuestion()
        checkPhotos()
    }

    // MARK: - Photo Check

    /// Looks up which buildings have a Wikipedia photo, the next ones in the
    /// queue first. Until a building is checked it simply gets no photo question.
    private func checkPhotos() {
        let upcoming = buildingQueue + [currentBuilding].compactMap { $0 }
        Task { [weak self] in
            for building in upcoming {
                // Cached by WikimediaService, so buildings seen on the city page are instant
                let summary = await WikimediaService.shared.summary(for: building.name, buildingID: building.id)
                guard let self else { return }
                if summary.photoURL != nil {
                    self.buildingsWithPhotos.insert(building.id)
                }
            }
        }
    }

    /// The photo failed to load: never show a photo question for this building
    /// again, and if it's on screen now, ask something else about it instead.
    func photoUnavailable(for buildingID: String) {
        buildingsWithPhotos.remove(buildingID)
        guard isPhotoQuestion, selectedOption == nil,
              let building = currentBuilding, building.id == buildingID else { return }
        apply(QuizLogic.pick(from: QuizLogic.choices(for: building, hasPhoto: false), using: &generator))
    }

    // MARK: - Voice Input Logic
    func startVoiceInput(reduceMotion: Bool) {
        isListening = true
        transcribedText = "Listening..."

        speechManager.startRecording { [weak self] text in
            Task { @MainActor in
                guard let self = self else { return }
                self.transcribedText = text
                // Year and floor answers must match the number said; names match by words
                let isNumeric = self.currentQuestionType == .year || self.currentQuestionType == .stories
                if let option = QuizLogic.voiceMatch(spoken: text, options: self.options, isNumeric: isNumeric) {
                    self.stopVoiceInput()
                    self.processAnswer(option, reduceMotion: reduceMotion)
                }
            }
        }
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

    // MARK: - Prompts

    var promptText: String {
        isPhotoQuestion ? QuestionType.photoPrompt : currentQuestionType.prompt
    }

    var voicePromptText: String {
        isPhotoQuestion ? QuestionType.photoVoicePrompt : currentQuestionType.voicePrompt
    }

    // MARK: - Quiz Logic

    func generateQuestion() {
        showHint = false
        if questionCount >= maxQuestions {
            isGameOver = true
            return
        }
        // Refill queue by shuffling — guarantees no immediate back-to-back repeats
        if buildingQueue.isEmpty {
            buildingQueue = buildings.shuffled()
        }
        let building = buildingQueue.removeFirst()
        currentBuilding = building
        // Only questions with a real answer; floors come up less often (see QuizLogic)
        let choices = QuizLogic.choices(for: building, hasPhoto: buildingsWithPhotos.contains(building.id))
        questionCount += 1
        apply(QuizLogic.pick(from: choices, using: &generator))
    }

    private func apply(_ choice: QuizLogic.Choice) {
        currentQuestionType = choice.type
        isPhotoQuestion = choice.showsPhoto
        setupOptions()
    }

    func setupOptions() {
        guard let building = currentBuilding else { return }
        let correct = getCorrectAnswer()
        let knownYear = building.hasKnownYear ? building.yearBuilt : nil

        // Three wrong answers, never repeated and never the right one.
        // A small city may have fewer, so the question just shows fewer options.
        let distractors: [String]
        switch currentQuestionType {
        case .name:
            distractors = QuizLogic.uniqueDistractors(for: correct, from: buildings.map(\.name), using: &generator)
        case .architect:
            // "Unknown" is never offered as a wrong answer
            distractors = QuizLogic.uniqueDistractors(for: correct, from: buildings.compactMap(\.knownArchitect), using: &generator)
        case .year:
            // Years close to the real one, not other buildings' years from other centuries
            distractors = QuizLogic.yearDistractors(for: building.yearBuilt, using: &generator).map(String.init)
        case .style:
            // Styles from a similar era first, so "Brutalist" isn't an easy miss for a 1600s church
            let pool = buildings.compactMap { other in
                other.knownStyle.map { (style: $0, year: other.hasKnownYear ? Optional(other.yearBuilt) : nil) }
            }
            distractors = QuizLogic.styleDistractors(for: correct, answerYear: knownYear, pool: pool, using: &generator)
        case .stories:
            distractors = QuizLogic.floorDistractors(for: building.numberOfStories, using: &generator).map { L.QuizExtra.floors($0) }
        }

        options = (distractors + [correct]).shuffled(using: &generator)
    }

    func getCorrectAnswer() -> String {
        guard let b = currentBuilding else { return "" }
        switch currentQuestionType {
        case .name: return b.name
        case .architect: return b.architect
        case .year: return "\(b.yearBuilt)"
        case .style: return b.buildingStyle
        case .stories: return L.QuizExtra.floors(b.numberOfStories)
        }
    }

    func processAnswer(_ selected: String, reduceMotion: Bool) {
        // A late voice result can't answer the same question twice
        guard selectedOption == nil else { return }
        if isListening { stopVoiceInput() }
        selectedOption = selected
        let correct = getCorrectAnswer()
        let isCorrect = (selected == correct)

        // Read the verdict and the building's facts, the same line shown on screen
        let verdict = isCorrect ? L.QuizExtra.correct : L.QuizExtra.incorrect(correct)
        UIAccessibility.post(notification: .announcement, argument: "\(verdict) \(factLine)")

        if isCorrect {
            score += 1
            currentStreak += 1
            if currentStreak > bestStreak { bestStreak = currentStreak }
            if score > highScore {
                highScore = score
                brokeHighScore = true
            }
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
            if let building = currentBuilding {
                misses.append(QuizMiss(buildingName: building.name, questionType: currentQuestionType,
                                       isPhoto: isPhotoQuestion, correctAnswer: correct, givenAnswer: selected))
            }

            HapticManager.shared.trigger(.error)

            if !reduceMotion {
                withAnimation(.default) { shakeTrigger += 1 }
            }
        }
        // No auto-advance: the player reads the facts line, then taps Next.
    }

    /// Moves on from an answered question (to the results after the last one).
    func nextQuestion(reduceMotion: Bool) {
        withAnimation(reduceMotion ? .none : .easeInOut) {
            selectedOption = nil
            generateQuestion()
        }
    }

    var isLastQuestion: Bool { questionCount >= maxQuestions }

    /// Shown after each answer: "Notre-Dame Basilica · Gothic Revival · 1829 · James O'Donnell"
    var factLine: String {
        currentBuilding.map(QuizLogic.factLine) ?? ""
    }

    func getHintText() -> String {
        guard let b = currentBuilding else { return "" }
        if isPhotoQuestion { return photoHint(for: b) }
        switch currentQuestionType {
        case .name:
            return "This landmark is in \(cityName) and is a prime example of \(b.buildingStyle) design."
        case .architect:
            // Without a year the decade hint would read "the 0s".
            guard b.hasKnownYear else {
                return "This landmark is a prime example of \(b.buildingStyle) design."
            }
            return "The architect is also known for work during the \(b.yearBuilt / 10 * 10)s."
        case .year:
            let era = b.yearBuilt < 1945 ? "pre-war" : "modernist"
            return "This was a major \(era) project designed by \(b.architect)."
        case .style:
            guard b.hasKnownYear else {
                return "This landmark is one of \(cityName)'s best-known sights."
            }
            return "Year \(b.yearBuilt) — this style dominated architecture in that era."
        case .stories:
            return "With its \(b.buildingStyle) design, this building was considered tall for its time."
        }
    }

    /// Era or architect, never the name (that's the answer)
    private func photoHint(for b: Building) -> String {
        // String(year) so the year never gets a thousands separator ("1,829")
        let year = String(b.yearBuilt)
        if let architect = b.knownArchitect, b.hasKnownYear {
            return String(localized: "Designed by \(architect) and completed in \(year).")
        }
        if let architect = b.knownArchitect {
            return String(localized: "Designed by \(architect).")
        }
        if b.hasKnownYear {
            return String(localized: "Completed in \(year).")
        }
        if let style = b.knownStyle {
            return String(localized: "A fine example of \(style) design.")
        }
        return String(localized: "This landmark is in \(cityName).")
    }

    // MARK: - Results Helpers

    var starCount: Int {
        if score >= 9 { return 3 }
        if score >= 6 { return 2 }
        if score >= 3 { return 1 }
        return 0
    }

    var resultMessage: String {
        switch starCount {
        case 3: return score == 10 ? "Perfect Score!" : "Outstanding!"
        case 2: return "Well Done!"
        case 1: return "Keep Practicing!"
        default: return "Try Again!"
        }
    }

    // MARK: - Audio Logic
    func playSound(named id: SystemSoundID) {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(id)
    }
}

// MARK: - Missed Question

/// One wrong answer, listed under "Review your misses" on the results screen.
struct QuizMiss: Identifiable {
    let id = UUID()
    let buildingName: String
    let questionType: QuestionType
    let isPhoto: Bool
    let correctAnswer: String
    let givenAnswer: String
}
