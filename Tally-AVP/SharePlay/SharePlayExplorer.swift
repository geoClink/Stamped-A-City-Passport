//
//  SharePlayExplorer.swift
//  Tally-AVP
//
//  Runs one "Explore <city> together" SharePlay session. It keeps everyone on the
//  same city (the activity's cityName) and passes the open landmark between
//  participants as a small ExploreMessage. Views read its properties; the map
//  reports landmark taps with landmarkOpened(_:in:).
//

import Combine      // the session's $state, $activity and $activeParticipants are Combine publishers
import Foundation
import GroupActivities
import Observation

@MainActor
@Observable
final class SharePlayExplorer {
    static let shared = SharePlayExplorer()

    /// True while this device is in an Explore Together session.
    private(set) var isSharing = false
    /// The city everyone in the session is looking at.
    private(set) var sharedCity: String?
    /// People in the session, including you.
    private(set) var participantCount = 0
    /// The landmark a friend last opened (or closed). A new value every time, so
    /// opening the same landmark twice still reaches the map's onChange.
    private(set) var remoteLandmark: RemoteLandmark?

    struct RemoteLandmark: Equatable {
        let id = UUID()
        let message: ExploreMessage
    }

    @ObservationIgnored private var session: GroupSession<ExploreCityActivity>?
    @ObservationIgnored private var messenger: GroupSessionMessenger?
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []
    /// The landmark open for the group right now; sent to people who join late.
    @ObservationIgnored private var currentSelection: ExploreMessage?
    @ObservationIgnored private var isListening = false

    private init() {}

    // MARK: - Starting and leaving

    /// Waits for SharePlay sessions for this app, started here or by a friend.
    /// Called once from the main window; extra calls return straight away.
    func listenForSessions() async {
        guard !isListening else { return }
        isListening = true
        for await session in ExploreCityActivity.sessions() {
            await join(session)
        }
    }

    /// Starts SharePlay for a city when already on a FaceTime call.
    /// (Without a call, the city map shows a ShareLink instead; see SharePlayButton.)
    func start(_ cityName: String) async {
        do {
            _ = try await ExploreCityActivity(cityName: cityName).activate()
        } catch {
            print("SharePlay: couldn't start Explore Together: \(error)")
        }
    }

    /// Leaves the session on this device; the others carry on without you.
    func leave() {
        session?.leave()
        reset()
    }

    // MARK: - Sending

    /// The user picked another city: move the whole group there.
    func cityChanged(to cityName: String?) {
        guard let session, let cityName, session.activity.cityName != cityName else { return }
        currentSelection = nil
        remoteLandmark = nil
        // Set now, not when the activity update echoes back, so the new city's
        // first landmark tap is already shared
        sharedCity = cityName
        session.activity = ExploreCityActivity(cityName: cityName)
    }

    /// The user opened a landmark's card (or closed it, with nil). Tells the group.
    func landmarkOpened(_ landmarkID: String?, in cityName: String) {
        guard let messenger,
              let message = Self.messageToSend(landmarkID: landmarkID, cityName: cityName,
                                               sharedCity: sharedCity, current: currentSelection)
        else { return }
        currentSelection = message
        Task {
            do {
                try await messenger.send(message)
            } catch {
                print("SharePlay: couldn't send landmark: \(error)")
            }
        }
    }

    // MARK: - Rules (static so tests can check them without a FaceTime call)

    /// The message to send for a local landmark tap, or nil when there's nothing to
    /// send: not sharing, a different city from the group's, or no change.
    static func messageToSend(landmarkID: String?, cityName: String,
                              sharedCity: String?, current: ExploreMessage?) -> ExploreMessage? {
        guard cityName == sharedCity else { return nil }
        let message = ExploreMessage(cityName: cityName, landmarkID: landmarkID)
        return message == current ? nil : message
    }

    /// Only messages about the group's current city are applied.
    static func shouldApply(_ message: ExploreMessage, sharedCity: String?) -> Bool {
        message.cityName == sharedCity
    }

    // MARK: - Session plumbing

    private func join(_ newSession: GroupSession<ExploreCityActivity>) async {
        leave()     // one session at a time
        session = newSession
        let newMessenger = GroupSessionMessenger(session: newSession)
        messenger = newMessenger
        sharedCity = newSession.activity.cityName

        // Spatial Personas stand side by side, all facing the shared map window.
        if let coordinator = await newSession.systemCoordinator {
            var configuration = SystemCoordinator.Configuration()
            configuration.spatialTemplatePreference = .sideBySide
            coordinator.configuration = configuration
        }

        // Session ended (everyone left, or the call hung up)
        tasks.append(Task {
            for await state in newSession.$state.values {
                if case .invalidated = state { reset() }
            }
        })
        // Someone moved the group to another city
        tasks.append(Task {
            for await activity in newSession.$activity.values {
                sharedCity = activity.cityName
            }
        })
        // Count people, and catch up anyone who joins late on the open landmark
        tasks.append(Task {
            var known = Set<Participant>()
            for await participants in newSession.$activeParticipants.values {
                participantCount = participants.count
                let newcomers = participants.subtracting(known).subtracting([newSession.localParticipant])
                known = participants
                if !newcomers.isEmpty, let currentSelection {
                    try? await newMessenger.send(currentSelection, to: .only(newcomers))
                }
            }
        })
        // A friend opened or closed a landmark
        tasks.append(Task {
            for await (message, _) in newMessenger.messages(of: ExploreMessage.self) {
                guard Self.shouldApply(message, sharedCity: sharedCity) else { continue }
                currentSelection = message
                remoteLandmark = RemoteLandmark(message: message)
            }
        })

        isSharing = true
        newSession.join()
    }

    private func reset() {
        tasks.forEach { $0.cancel() }
        tasks = []
        session = nil
        messenger = nil
        currentSelection = nil
        isSharing = false
        sharedCity = nil
        participantCount = 0
        remoteLandmark = nil
    }
}
