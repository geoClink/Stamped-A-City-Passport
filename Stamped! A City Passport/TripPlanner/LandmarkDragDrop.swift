//
//  LandmarkDragDrop.swift
//  Stamped! A City Passport
//
//  Drag and drop for landmarks (2.10), on Mac and iPad: drag a landmark row from a
//  city page onto a trip day, or onto a trip in a trip list, to add it as a stop.
//  Dragged into another app (Notes, Mail), a landmark becomes its name as text.
//

import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

/// What a dragged landmark carries. Building ids are unique across every city,
/// so the id alone says which landmark it is.
struct LandmarkDragItem: Codable, Transferable {
    let buildingID: String

    static var transferRepresentation: some TransferRepresentation {
        // Inside the app: the id, as JSON. (A custom type would need declaring in the
        // Info.plist; anything that isn't a landmark fails to decode and is ignored.)
        CodableRepresentation(contentType: .json)
        // Other apps: the landmark's name, as plain text (export only)
        ProxyRepresentation(exporting: { item in
            LandmarkIndex.building(withID: item.buildingID)?.name ?? ""
        })
    }
}

extension Trip {
    /// Whether a landmark can go on this day. A city trip takes its own city's landmarks;
    /// a road trip day takes its campus's (any campus while the day is still empty);
    /// an anywhere trip only holds Apple Maps places, so it takes none.
    func accepts(landmarkID: String, onDayAt index: Int) -> Bool {
        guard let landmarkCity = LandmarkIndex.city(ofBuilding: landmarkID) else { return false }
        if let listedCity {
            return landmarkCity == listedCity
        }
        if isRoadTrip {
            if let dayCity = city(ofDayAt: index) { return dayCity == landmarkCity }
            return landmarkCity.isCampus
        }
        return false
    }
}

extension TripStore {
    /// Adds dropped landmarks to a day, starting at `index` (the end of the day when nil).
    /// Skips ones that don't belong on this trip or are already on the day.
    /// Returns false when nothing was added, so the drop shows as refused.
    @discardableResult
    func addDroppedLandmarks(_ items: [LandmarkDragItem], toDay dayID: String, at index: Int? = nil, in tripID: String) -> Bool {
        var insertAt = index
        var addedAny = false
        for item in items {
            // Look the trip up each time: the first landmark can decide a road trip day's campus
            guard let trip = trip(withID: tripID),
                  let dayIndex = trip.days.firstIndex(where: { $0.id == dayID }),
                  trip.accepts(landmarkID: item.buildingID, onDayAt: dayIndex),
                  !trip.days[dayIndex].landmarkIDs.contains(item.buildingID),
                  let stopID = addStop(.landmark(buildingID: item.buildingID), toDay: dayID, in: tripID)
            else { continue }

            // addStop puts it at the end; move it to where it was dropped
            if let position = insertAt {
                moveStop(stopID, toDay: dayID, at: position, in: tripID)
                insertAt = position + 1
            }
            addedAny = true
        }
        if addedAny { HapticManager.shared.trigger(.success) }
        return addedAny
    }
}

extension View {
    /// Lets this landmark be dragged on Mac and iPad. iPhone shows one screen at a time,
    /// with nowhere to drop it, so a long press there stays the context menu only.
    @ViewBuilder
    func landmarkDraggable(_ building: Building) -> some View {
        if DeviceInfo.isLargeScreen {
            draggable(LandmarkDragItem(buildingID: building.id)) {
                Label(building.name, systemImage: "mappin.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, DS.Space.m)
                    .padding(.vertical, DS.Space.s)
                    .background(.regularMaterial, in: Capsule())
            }
        } else {
            self
        }
    }

    /// A trip row that takes dropped landmarks, adding them to the end of its last day.
    func acceptsLandmarkDrops(onto trip: Trip) -> some View {
        modifier(TripRowDropTarget(trip: trip))
    }
}

/// Outlines a trip row in orange while a landmark is dragged over it.
private struct TripRowDropTarget: ViewModifier {
    let trip: Trip
    @State private var isTargeted = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                        .stroke(DS.Palette.accent, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .dropDestination(for: LandmarkDragItem.self) { items, _ in
                guard let lastDay = trip.days.last else { return false }
                return TripStore.shared.addDroppedLandmarks(items, toDay: lastDay.id, in: trip.id)
            } isTargeted: { isTargeted = $0 }
    }
}
