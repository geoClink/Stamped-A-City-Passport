//
//  AskBuildingView.swift
//  Tally-AVP
//
//  Ask the building: type or dictate a question and the landmark answers, in the
//  first person, using only the app's own facts about it (its description, dates,
//  architect, style and timeline). Apple's on-device model writes the answer, so
//  nothing leaves the device; it's told to say it doesn't know rather than guess.
//  The answer is read aloud.
//

import SwiftUI
import FoundationModels
import AVFoundation

struct AskBuildingView: View {
    let building: Building
    let cityName: String

    @Environment(\.dismiss) private var dismiss
    @State private var question = ""
    @State private var answers: [(question: String, answer: String)] = []
    @State private var isThinking = false
    @State private var session: LanguageModelSession?
    @State private var speaker = AVSpeechSynthesizer()
    @FocusState private var fieldFocused: Bool

    private var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    private let suggestions = [
        String(localized: "When were you built?"), String(localized: "Who designed you?"),
        String(localized: "What were you used for?"), String(localized: "What happened here?"),
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if !isAvailable {
                    ContentUnavailableView(
                        "Apple Intelligence Is Off",
                        systemImage: "apple.intelligence",
                        description: Text("Turn on Apple Intelligence in Settings to ask landmarks questions.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(answers.indices, id: \.self) { index in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(answers[index].question).font(.headline)
                                    Text(answers[index].answer).font(.body)
                                }
                            }
                            if isThinking {
                                ProgressView().padding(.vertical, 4)
                            }
                            if answers.isEmpty && !isThinking {
                                // A few questions to start with
                                FlowRow(suggestions) { suggestion in
                                    Button(suggestion) { ask(suggestion) }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack {
                        // The keyboard's microphone dictates the question
                        TextField("Ask \(building.name) a question", text: $question)
                            .textFieldStyle(.roundedBorder)
                            .focused($fieldFocused)
                            .onSubmit { ask(question) }
                        Button("Ask") { ask(question) }
                            .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || isThinking)
                    }
                    Text("Answers come only from Stamped's facts about this landmark, written on your device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .navigationTitle(Text("Ask \(building.name)"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 520)
        .task(id: building.id) { await startSession() }
        .onDisappear { speaker.stopSpeaking(at: .immediate) }
    }

    // MARK: - Asking

    private func ask(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking, let session else { return }
        question = ""
        isThinking = true
        Task {
            let answer: String
            do {
                answer = try await session.respond(to: text).content
            } catch {
                answer = String(localized: "Sorry, I couldn't answer that just now.")
            }
            answers.append((text, answer))
            isThinking = false
            speak(answer)
        }
    }

    private func speak(_ text: String) {
        speaker.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.language.minimalIdentifier)
        speaker.speak(utterance)
    }

    /// One conversation per landmark, primed with everything Stamped knows about it
    private func startSession() async {
        guard isAvailable else { return }
        let timeline = await HistoryTimelineService.shared.timeline(for: building)
        session = LanguageModelSession(instructions: Self.instructions(for: building, cityName: cityName,
                                                                       timeline: timeline))
    }

    nonisolated static func instructions(for building: Building, cityName: String,
                                         timeline: [HistoryEvent]) -> String {
        var facts = ["Name: \(building.name)", "City: \(cityName)"]
        if !building.address.isEmpty { facts.append("Address: \(building.address)") }
        if building.hasKnownYear { facts.append("Year finished: \(building.yearBuilt)") }
        if let architect = building.knownArchitect { facts.append("Architect: \(architect)") }
        if let style = building.knownStyle { facts.append("Style: \(style)") }
        if !building.oldUse.isEmpty { facts.append("Original use: \(building.oldUse)") }
        if !building.newUse.isEmpty { facts.append("Use today: \(building.newUse)") }
        if building.numberOfStories > 0 { facts.append("Stories: \(building.numberOfStories)") }
        if building.height > 0 { facts.append("Height: \(Int(building.height)) m") }
        for event in timeline {
            let what = [event.kind.rawValue, event.label].compactMap { $0 }.joined(separator: ": ")
            facts.append("\(event.year): \(what)")
        }
        facts.append("About: \(building.description)")

        return """
        You are \(building.name), a landmark in \(cityName), answering a visitor's question \
        in the first person ("I was built in…"). Use ONLY the facts below. If the facts don't \
        answer the question, say kindly that you don't know. Never invent names, dates or numbers. \
        Answer in two or three short sentences, in the language of the question.

        FACTS:
        \(facts.joined(separator: "\n"))
        """
    }
}

/// Buttons that wrap onto more lines when they don't fit on one
private struct FlowRow<Item, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    init(_ items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack { ForEach(items.indices, id: \.self) { content(items[$0]) } }
            VStack(alignment: .leading) { ForEach(items.indices, id: \.self) { content(items[$0]) } }
        }
    }
}
