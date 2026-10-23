//
//  VisionQuizView.swift
//  Tally-AVP
//
//  Ten-question architecture quiz for one city, using the same question types
//  as the iPhone quiz (QuestionType is shared between the two apps).
//

import SwiftUI

struct VisionQuizView: View {
    let cityName: String
    let buildings: [Building]

    @Environment(\.dismiss) private var dismiss
    @State private var quiz: QuizRound

    init(cityName: String, buildings: [Building]) {
        self.cityName = cityName
        self.buildings = buildings
        _quiz = State(initialValue: QuizRound(buildings: buildings))
    }

    var body: some View {
        NavigationStack {
            Group {
                if quiz.isFinished {
                    results
                } else if let building = quiz.building {
                    question(for: building)
                } else {
                    ContentUnavailableView("Not enough landmarks for a quiz", systemImage: "questionmark.circle")
                }
            }
            .padding(40)
            .navigationTitle("\(cityName) Quiz")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 700, minHeight: 600)
    }

    // MARK: - Question

    private func question(for building: Building) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Question \(quiz.questionNumber) of \(QuizRound.length)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Label("\(quiz.score)", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }
            ProgressView(value: Double(quiz.questionNumber - 1), total: Double(QuizRound.length))
                .tint(.orange)

            // A clue card about the building (hides whatever is being asked)
            VStack(alignment: .leading, spacing: 8) {
                if quiz.type != .name { Text(building.name).font(.title2.bold()) }
                Text(building.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 24))

            Text(quiz.type.prompt)
                .font(.title.bold())

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(quiz.options, id: \.self) { option in
                    Button {
                        quiz.answer(option)
                        // Short pause so the green/red colours can be seen, then move on
                        Task {
                            try? await Task.sleep(for: .seconds(1.2))
                            withAnimation { quiz.nextQuestion() }
                        }
                    } label: {
                        Text(option)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 70)
                    }
                    .tint(tint(for: option))
                    .disabled(quiz.selected != nil)
                }
            }
        }
    }

    /// After answering: the right answer turns green, a wrong pick turns red.
    private func tint(for option: String) -> Color? {
        guard let selected = quiz.selected else { return nil }
        if option == quiz.correctAnswer { return .green }
        if option == selected { return .red }
        return nil
    }

    // MARK: - Results

    private var results: some View {
        VStack(spacing: 20) {
            Image(systemName: quiz.score >= 8 ? "rosette" : "checkmark.seal")
                .font(.system(size: 80))
                .foregroundStyle(.orange)
            Text("\(quiz.score) out of \(QuizRound.length)")
                .font(.extraLargeTitle)
            Text(quiz.score == QuizRound.length ? "Perfect score!" : quiz.score >= 6 ? "Well done!" : "Keep exploring and try again.")
                .font(.title2)
                .foregroundStyle(.secondary)
            Button("Play Again") { quiz = QuizRound(buildings: buildings) }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Quiz state

/// One round of 10 questions. A plain struct held in @State, like a small model in SwiftUI.
struct QuizRound {
    static let length = 10

    private let buildings: [Building]
    private var queue: [Building]
    private(set) var building: Building?
    private(set) var type: QuestionType = .name
    private(set) var options: [String] = []
    private(set) var selected: String?
    private(set) var score = 0
    private(set) var questionNumber = 0

    var isFinished: Bool { questionNumber > Self.length }

    init(buildings: [Building]) {
        self.buildings = buildings
        self.queue = buildings.shuffled()
        nextQuestion()
    }

    var correctAnswer: String {
        guard let building else { return "" }
        return Self.answer(type, for: building)
    }

    mutating func answer(_ option: String) {
        guard selected == nil else { return }
        selected = option
        if option == correctAnswer { score += 1 }
    }

    mutating func nextQuestion() {
        selected = nil
        questionNumber += 1
        guard questionNumber <= Self.length, buildings.count >= 4 else { building = nil; return }
        if queue.isEmpty { queue = buildings.shuffled() }
        let next = queue.removeFirst()
        building = next
        type = Self.types(for: next).randomElement() ?? .name

        let correct = Self.answer(type, for: next)
        let others = Set(buildings.map { Self.answer(type, for: $0) }).subtracting([correct, ""])
        options = (Array(others.shuffled().prefix(3)) + [correct]).shuffled()
    }

    /// Only ask about things this building actually has data for (same rule as iPhone).
    private static func types(for building: Building) -> [QuestionType] {
        var types: [QuestionType] = [.name, .style, .year]
        let architect = building.architect.trimmingCharacters(in: .whitespaces)
        if !architect.isEmpty && architect.lowercased() != "unknown" { types.append(.architect) }
        if building.numberOfStories > 0 { types.append(.stories) }
        return types
    }

    private static func answer(_ type: QuestionType, for building: Building) -> String {
        switch type {
        case .name: building.name
        case .style: building.buildingStyle
        case .year: String(building.yearBuilt)
        case .architect: building.architect
        case .stories: "\(building.numberOfStories) floors"
        }
    }
}
