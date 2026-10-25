//
//  CollegeListButton.swift
//  Stamped! A City Passport
//
//  A small heart button for a campus page: adds the campus to My College
//  List, or takes it off. Sized like a toolbar button, so it fits in a
//  navigation bar or next to the campus name.
//

import SwiftUI

struct CollegeListButton: View {
    let campus: CityLocation.City

    @ObservedObject private var store = CollegeListStore.shared
    @AppStorage("high_contrast_mode") private var isHighContrast = false

    private var isOnList: Bool { store.contains(campus) }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                store.toggle(campus)
            }
            HapticManager.shared.trigger(isOnList ? .success : .selection)
        } label: {
            Image(systemName: isOnList ? "heart.fill" : "heart")
                .font(.title3.weight(isHighContrast ? .bold : .semibold))
                .foregroundStyle(isOnList && !isHighContrast ? DS.Palette.accent : Color.primary)
                .contentTransition(.symbolEffect(.replace))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isOnList
                ? NSLocalizedString("Remove from My College List", comment: "Campus page: VoiceOver label for the college list button when the campus is on the list")
                : NSLocalizedString("Add to My College List", comment: "Campus page: VoiceOver label for the college list button when the campus isn't on the list")
        )
        .accessibilityValue(
            isOnList
                ? NSLocalizedString("On your list", comment: "Campus page: VoiceOver value of the college list button when the campus is on the list")
                : ""
        )
        .accessibilityAddTraits(isOnList ? .isSelected : [])
        .help(isOnList
              ? NSLocalizedString("Remove from My College List", comment: "Campus page: VoiceOver label for the college list button when the campus is on the list")
              : NSLocalizedString("Add to My College List", comment: "Campus page: VoiceOver label for the college list button when the campus isn't on the list"))
        // Only campuses can go on the list
        .opacity(campus.isCampus ? 1 : 0)
        .disabled(!campus.isCampus)
        .accessibilityHidden(!campus.isCampus)
    }
}

#Preview {
    CollegeListButton(campus: .duke)
}
