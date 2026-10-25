//
//  CollegeListView.swift
//  Stamped! A City Passport
//
//  "My College List": the campuses a prospective student is considering.
//  Each row shows the school's conference, nickname, landmark count and how
//  many landmarks are stamped. Swipe to remove, Edit to reorder, and
//  "Plan a College Road Trip" makes one trip with a day per school, which
//  then opens in My Trips.
//
//  Present it as a sheet; it has its own NavigationStack and Done button.
//

import SwiftUI

struct CollegeListView: View {
    /// Called when a school is tapped. Leave nil to open the campus page
    /// inside this screen's own navigation.
    var onOpenCampus: ((CityLocation.City) -> Void)? = nil

    @ObservedObject private var store = CollegeListStore.shared
    @ObservedObject private var progress = GlobalProgressManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage("high_contrast_mode") private var isHighContrast = false

    @State private var showingRoadTripPlanner = false
    /// The trip just made, opened in My Trips once the planner sheet has closed.
    @State private var createdTripID: String?
    @State private var openTrip: OpenTrip?

    private struct OpenTrip: Identifiable {
        let id: String
    }

    var body: some View {
        NavigationStack {
            List {
                if store.isEmpty {
                    emptyState
                } else {
                    Section {
                        roadTripButton
                    }

                    Section {
                        ForEach(store.campuses) { campus in
                            campusRow(campus)
                        }
                        .onDelete { store.remove(atOffsets: $0) }
                        .onMove { store.move(fromOffsets: $0, toOffset: $1) }
                    } header: {
                        // Interpolated: schoolCountText is already localized
                        DSSectionHeader("\(schoolCountText)", systemImage: "graduationcap", isHighContrast: isHighContrast)
                    } footer: {
                        Text(NSLocalizedString("Tap the heart on any campus page to add it here.", comment: "College list: footer under the list of schools"))
                    }
                }
            }
            .navigationTitle(NSLocalizedString("My College List", comment: "College list: screen title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Done", comment: "College list: closes the screen")) { dismiss() }
                }
                if !store.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        EditButton()
                    }
                }
            }
            .navigationDestination(for: CityLocation.City.self) { campus in
                ScrollView {
                    CityDetailView(city: campus)
                }
                .background(DS.Palette.pageBackground)
            }
        }
        .tint(DS.Palette.accent)
        .sheet(isPresented: $showingRoadTripPlanner, onDismiss: openCreatedTrip) {
            CollegeRoadTripSheet(campuses: store.campuses) { trip in
                createdTripID = trip.id
            }
        }
        // Like the city list's My Trips: a sheet on iPhone, full screen on iPad
        .sheet(item: openTripBinding(fullScreen: false)) { MyTripsView(initialTripID: $0.id) }
        .fullScreenCover(item: openTripBinding(fullScreen: true)) { MyTripsView(initialTripID: $0.id) }
    }

    // MARK: - Pieces

    private var schoolCountText: String {
        let count = store.campuses.count
        return count == 1
            ? NSLocalizedString("1 school", comment: "College list: section header when one school is saved")
            : String(format: NSLocalizedString("%d schools", comment: "College list: section header, e.g. \"4 schools\""), count)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(NSLocalizedString("No Schools Yet", comment: "College list: empty state title"), systemImage: "graduationcap")
        } description: {
            Text(NSLocalizedString("Open any campus in Campus Architecture and tap the heart to add it to your list. Then plan a road trip that visits them all, one campus a day.", comment: "College list: empty state explaining how to add schools"))
        }
        .listRowBackground(Color.clear)
    }

    private var roadTripButton: some View {
        Button {
            HapticManager.shared.trigger(.selection)
            showingRoadTripPlanner = true
        } label: {
            // HStack rather than Label: inside a List row, Label can drop its icon
            HStack(spacing: DS.Space.s) {
                Image(systemName: "car.fill")
                Text(NSLocalizedString("Plan a College Road Trip", comment: "College list: button that makes one trip visiting the saved schools"))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .font(.headline)
            .fontWeight(isHighContrast ? .black : .semibold)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(DS.Palette.accent)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .accessibilityHint(NSLocalizedString("Makes one trip with a day at each school, in a short driving order.", comment: "College list: VoiceOver hint for the Plan a College Road Trip button"))
    }

    @ViewBuilder
    private func campusRow(_ campus: CityLocation.City) -> some View {
        if let onOpenCampus {
            Button {
                onOpenCampus(campus)
            } label: {
                CollegeListRow(campus: campus, progress: progress, isHighContrast: isHighContrast)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: campus) {
                CollegeListRow(campus: campus, progress: progress, isHighContrast: isHighContrast)
            }
        }
    }

    // MARK: - Opening the new trip

    private func openCreatedTrip() {
        guard let createdTripID else { return }
        self.createdTripID = nil
        openTrip = OpenTrip(id: createdTripID)
    }

    private func openTripBinding(fullScreen: Bool) -> Binding<OpenTrip?> {
        Binding(
            get: { (sizeClass == .regular) == fullScreen ? openTrip : nil },
            set: { openTrip = $0 }
        )
    }
}

/// One school: name, conference (or country), nickname, landmarks and stamps.
private struct CollegeListRow: View {
    let campus: CityLocation.City
    @ObservedObject var progress: GlobalProgressManager
    let isHighContrast: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var groupName: String {
        if let conference = campus.conference, conference != .other {
            return conference.name
        }
        return campus.country.localizedName
    }

    /// The nickname, unless it's just the name again (the fallback when a campus has none).
    private var nickname: String? {
        let nickname = campus.details.nickname
        return nickname.isEmpty || nickname == campus.name ? nil : nickname
    }

    var body: some View {
        let buildings = campus.buildings
        let stamped = buildings.filter { progress.isVisited($0.id) }.count

        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(campus.name)
                // Serif, the style guide's type for destinations
                .font(.system(.headline, design: .serif))
                .fontWeight(isHighContrast ? .black : .semibold)
                .foregroundStyle(.primary)

            Text(nickname.map { "\(groupName) · \($0)" } ?? groupName)
                .font(.subheadline)
                .foregroundStyle(isHighContrast ? .primary : .secondary)
                .lineLimit(2)

            // The bar goes under the text at accessibility sizes, so the text keeps the full width
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.xs))
                : AnyLayout(HStackLayout(spacing: DS.Space.s))
            layout {
                Text(String(
                    format: NSLocalizedString("%1$d of %2$d landmarks stamped", comment: "College list: stamp progress for a school, e.g. \"3 of 12 landmarks stamped\""),
                    stamped, buildings.count
                ))
                .font(.caption)
                .foregroundStyle(isHighContrast ? .primary : .secondary)

                if !buildings.isEmpty {
                    ProgressView(value: Double(stamped), total: Double(buildings.count))
                        .tint(isHighContrast ? Color.primary : DS.Palette.accent)
                        .frame(maxWidth: 80)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.vertical, DS.Space.xs)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    CollegeListView()
}
