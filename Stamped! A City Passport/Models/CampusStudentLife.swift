//
//  CampusStudentLife.swift
//  Stamped! A City Passport
//
//  "Student Life" on a campus page: where students live, eat, study and hang out.
//  Comes from tools/campus-data/build_student_life.py: CampusStudentLife.json
//  (English in Resources/, translated in each *.lproj/), like CampusTraditions.json.
//

import Foundation
import CoreLocation

/// A place a visiting student would want to see: a residence neighborhood, the union, a study spot...
struct StudentLifeSpot: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let category: Category
    let description: String
    let latitude: Double
    let longitude: Double

    /// What kind of place it is; the section groups spots in this order.
    enum Category: String, Codable, CaseIterable {
        case housing, union, study, dining, hangout

        var title: String {
            switch self {
            case .housing: NSLocalizedString("Where Students Live", comment: "Campus student life: header for residence-hall neighborhoods")
            case .union: NSLocalizedString("Student Union", comment: "Campus student life: header for the student union")
            case .study: NSLocalizedString("Study Spots", comment: "Campus student life: header for libraries and study spaces")
            case .dining: NSLocalizedString("Dining Halls", comment: "Campus student life: header for dining halls")
            case .hangout: NSLocalizedString("Hangouts", comment: "Campus student life: header for places students hang out")
            }
        }

        var systemImage: String {
            switch self {
            case .housing: "bed.double"
            case .union: "person.3"
            case .study: "books.vertical"
            case .dining: "fork.knife"
            case .hangout: "cup.and.saucer"
            }
        }
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Loads CampusStudentLife.json once; Bundle picks the copy for the app's language.
enum StudentLifeStore {
    private static let spotsByCampus: [String: [StudentLifeSpot]] = {
        guard let url = Bundle.main.url(forResource: "CampusStudentLife", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [StudentLifeSpot]].self, from: data)
        else { return [:] }
        return decoded
    }()

    static func spots(for campus: CityLocation.City) -> [StudentLifeSpot] {
        spotsByCampus[campus.rawValue] ?? []
    }
}

extension CityLocation.City {
    /// The campus's student-life spots (empty for cities and campuses without data yet).
    var studentLife: [StudentLifeSpot] { StudentLifeStore.spots(for: self) }
}
