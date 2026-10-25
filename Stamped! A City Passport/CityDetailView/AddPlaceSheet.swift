//
//  AddPlaceSheet.swift
//  Stamped! A City Passport
//
//  Search Apple Maps for any place in a city (restaurant, park, shop, venue…)
//  and save it to "Want to Visit".
//

import SwiftUI
import MapKit

struct AddPlaceSheet: View {
    let cityName: String
    /// Middle of the city, so results come from this city and not somewhere else.
    let cityCenter: CLLocationCoordinate2D

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var progress = GlobalProgressManager.shared
    @AppStorage("haptics_enabled") private var hapticsEnabled = true

    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            List(results, id: \.self) { item in
                resultRow(item)
            }
            .overlay {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    ContentUnavailableView(
                        "Add a Place in \(cityName)",
                        systemImage: "mappin.and.ellipse",
                        description: Text("Search for a restaurant, park, shop, museum or anything else you want to visit.")
                    )
                } else if isSearching && results.isEmpty {
                    ProgressView()
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search \(cityName)")
            .navigationTitle("Want to Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            // Re-runs whenever the text changes; the short sleep waits for the
            // user to pause typing so we don't search on every keystroke.
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                await search()
            }
        }
    }

    // MARK: - Row

    private func resultRow(_ item: MKMapItem) -> some View {
        let name = item.name ?? "Unnamed place"
        let coordinate = coordinate(of: item)
        let isSaved = progress.hasCustomPlace(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude)

        return Button {
            save(item)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon(for: item))
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(DS.Palette.wishlist, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.headline).foregroundStyle(.primary)
                    if let address = address(of: item) {
                        Text(address).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: isSaved ? "heart.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundStyle(DS.Palette.wishlist)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .disabled(isSaved)
        .accessibilityLabel(isSaved ? "\(name), saved" : "Save \(name)")
    }

    // MARK: - Actions

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { results = []; return }
        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.resultTypes = [.pointOfInterest, .address]
        // About 25 km around the city centre
        request.region = MKCoordinateRegion(center: cityCenter, latitudinalMeters: 25_000, longitudinalMeters: 25_000)
        let response = try? await MKLocalSearch(request: request).start()
        results = response?.mapItems ?? []
    }

    private func save(_ item: MKMapItem) {
        let coordinate = coordinate(of: item)
        let place = CustomPlace(
            id: UUID().uuidString,
            name: item.name ?? "Unnamed place",
            address: address(of: item),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            cityName: cityName,
            websiteURL: item.url,
            phoneNumber: item.phoneNumber,
            category: item.pointOfInterestCategory?.rawValue
        )
        withAnimation { progress.addCustomPlace(place) }
        if hapticsEnabled { HapticManager.shared.trigger(.success) }
    }

    // MARK: - Helpers

    // The app supports iOS 18.6, but these MKMapItem properties changed in iOS 26.
    // `#available` picks the right one at runtime, like an `if` on the OS version.
    private func coordinate(of item: MKMapItem) -> CLLocationCoordinate2D {
        if #available(iOS 26.0, *) {
            return item.location.coordinate
        } else {
            return item.placemark.coordinate
        }
    }

    private func address(of item: MKMapItem) -> String? {
        if #available(iOS 26.0, *) {
            return item.address?.shortAddress ?? item.address?.fullAddress
        } else {
            return item.placemark.title
        }
    }

    private func icon(for item: MKMapItem) -> String {
        CustomPlace.icon(forCategory: item.pointOfInterestCategory?.rawValue)
    }
}
