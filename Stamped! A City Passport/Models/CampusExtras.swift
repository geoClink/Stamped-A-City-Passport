//
//  CampusExtras.swift
//  Stamped! A City Passport
//
//  Campus traditions (the scavenger hunt) and school colors (the campus stamp).
//  Both come from tools/campus-data: traditions are in CampusTraditions.json
//  (English in Resources/, translated in each *.lproj/), colors in CampusList.swift.
//

import SwiftUI
import CoreLocation

/// Shown in Settings and on campus pages: the app uses school names and colors only to identify them.
enum CampusDisclaimer {
    static let text = NSLocalizedString(
        "Stamped! is not affiliated with or endorsed by any university. School names and colors are used only to identify them.",
        comment: "Settings and campus pages: legal note that the app is independent of the universities it lists"
    )
}

/// A campus tradition a visitor can do or see: "Rub John Harvard's foot", "Ring the Victory Bell".
struct CampusTradition: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Loads CampusTraditions.json once; Bundle picks the copy for the app's language.
enum CampusTraditionStore {
    private static let traditionsByCampus: [String: [CampusTradition]] = {
        guard let url = Bundle.main.url(forResource: "CampusTraditions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [CampusTradition]].self, from: data)
        else { return [:] }
        return decoded
    }()

    static func traditions(for campus: CityLocation.City) -> [CampusTradition] {
        traditionsByCampus[campus.rawValue] ?? []
    }
}

extension CityLocation.City {
    /// The campus's traditions for the scavenger hunt (empty for cities).
    var traditions: [CampusTradition] { CampusTraditionStore.traditions(for: self) }

    /// Official school colors, primary first (empty for cities and campuses without colors).
    var schoolColors: [Color] {
        (Self.campusColors[self] ?? []).compactMap { CampusHex($0)?.color }
    }

    /// The school color a campus stamp is inked in: the first one that stays readable on the
    /// stamp's background (Michigan's maize is too light on white, Oxford blue too dark on black).
    /// nil means "use the app's orange".
    func stampColor(darkMode: Bool) -> Color? {
        (Self.campusColors[self] ?? [])
            .compactMap(CampusHex.init)
            .first { darkMode ? $0.luminance > 0.12 : $0.luminance < 0.45 }?
            .color
    }
}

/// A "#18453B" color from the campus data (checked by the campus script).
private struct CampusHex {
    let red, green, blue: Double

    init?(_ hex: String) {
        guard hex.count == 7, hex.first == "#", let value = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        red = Double((value >> 16) & 0xFF) / 255
        green = Double((value >> 8) & 0xFF) / 255
        blue = Double(value & 0xFF) / 255
    }

    var color: Color { Color(red: red, green: green, blue: blue) }

    /// Relative luminance (WCAG), 0 = black, 1 = white.
    var luminance: Double {
        func channel(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }
}
