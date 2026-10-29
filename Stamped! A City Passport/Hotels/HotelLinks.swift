//
//  HotelLinks.swift
//  Stamped! A City Passport
//
//  "Find Hotels" links. Stamped never books or takes payment: these buttons open
//  a hotel site's own public search for a place and (when known) a check-in and
//  check-out date. Hotels support the architecture trip; they're never the main event.
//
//  • HotelPartner is the one place to choose the hotel site and set an affiliate ID.
//  • HotelSearch is what to search for; HotelLinkBuilder turns it into a URL.
//  • FindHotelsButton is the button the trip planner and the map's place card show.
//

import SwiftUI
import CoreLocation

// MARK: - Configuration

/// The single configuration point for hotel links.
enum HotelPartner {
    /// Which hotel site the "Find Hotels" and "Check Prices" buttons open.
    /// Expedia for now: its tracked links work today. Booking.com (applied through CJ,
    /// 29 Oct 2026) can come back once it's approved, alongside Expedia or instead of it.
    static let provider: HotelProvider = .expedia

    /// The affiliate ID for `provider`, or nil for plain public search links.
    ///
    /// Leave this nil until the provider's affiliate program approves the app. After
    /// approval, copy the ID from the partner dashboard and paste it here as a string:
    /// Booking.com: the "aid" that appears in every link its deep link builder makes.
    /// Expedia: the Partnerize camref, `expediaCamref` below.
    /// It is not a secret: it's sent in plain sight in every link a user opens, so it
    /// is fine to keep it in source control.
    ///
    /// While this is nil the links carry no tracking parameters at all, and the
    /// "may earn a commission" note stays hidden.
    static let affiliateID: String? = expediaCamref

    /// The Expedia Group Affiliate Program's Partnerize camref for this account, from the
    /// code the Creator Hub's Search widgets page generates (data-camref). Set
    /// `affiliateID` to this when `provider` is `.expedia`.
    static let expediaCamref = "1110lStp6"
}

/// How a provider's affiliate links carry the affiliate ID.
enum AffiliateTracking: Equatable {
    /// Added to the search link as a query parameter, e.g. Booking.com's "aid".
    case queryParameter(String)
    /// The search link is wrapped in a Partnerize click link:
    /// https://prf.hn/click/camref:<id>/destination:<encoded search link>.
    /// Checked 29 Oct 2026: it lands on the same Expedia search with the affiliate's
    /// tracking (affcid, clickref) added.
    case partnerize
}

/// The hotel sites Stamped can link to.
enum HotelProvider: String, CaseIterable, Identifiable {
    case booking, expedia, hotelsCom

    var id: Self { self }

    var displayName: String {
        switch self {
        case .booking:   "Booking.com"
        case .expedia:   "Expedia"
        case .hotelsCom: "Hotels.com"
        }
    }

    /// The public hotel search page. Formats checked against each site's live search
    /// pages (see HotelLinkBuilder for the parameters).
    fileprivate var searchEndpoint: String {
        switch self {
        case .booking:   "https://www.booking.com/searchresults.html"
        case .expedia:   "https://www.expedia.com/Hotel-Search"
        case .hotelsCom: "https://www.hotels.com/Hotel-Search"
        }
    }

    /// How the affiliate ID is carried, or nil when it hasn't been confirmed from the
    /// provider's partner program (then no ID is ever added).
    var affiliateTracking: AffiliateTracking? {
        switch self {
        case .booking:
            // Booking.com affiliate links carry the affiliate ID as "aid"
            // (e.g. https://www.booking.com/?aid=XXXXXXX). Booking now signs affiliates up
            // through CJ, so double-check against a link CJ generates once approved.
            .queryParameter("aid")
        case .expedia:
            .partnerize
        case .hotelsCom:
            // Hotels.com is a separate Partnerize campaign, so the Expedia camref doesn't
            // cover it. Until it has its own, a Hotels.com ID is ignored.
            nil
        }
    }
}

// MARK: - Search

/// What to search hotels for: a place, optionally a point on the map, and optional dates.
struct HotelSearch: Hashable {
    /// The text shown in the site's search box ("Duke University", "Paris, France").
    var destination: String
    /// Where to search around. The sites' free-text matching sometimes lands on the wrong
    /// place (a hotel whose name contains "GA", Athens in Greece instead of Georgia), so
    /// when a coordinate is known the search is centred on it and the text is just a label.
    var latitude: Double? = nil
    var longitude: Double? = nil
    /// The night of arrival. nil means no dates (the site asks for them).
    var checkIn: Date? = nil
    /// The morning of departure. Defaults to the day after `checkIn` when missing or not after it.
    var checkOut: Date? = nil

    init(destination: String, latitude: Double? = nil, longitude: Double? = nil, checkIn: Date? = nil, checkOut: Date? = nil) {
        self.destination = destination
        self.latitude = latitude
        self.longitude = longitude
        self.checkIn = checkIn
        self.checkOut = checkOut
    }

    init(destination: String, coordinate: CLLocationCoordinate2D?, checkIn: Date? = nil, checkOut: Date? = nil) {
        self.init(destination: destination, latitude: coordinate?.latitude, longitude: coordinate?.longitude,
                  checkIn: checkIn, checkOut: checkOut)
    }

    /// Hotels for a Stamped city or campus.
    init(city: CityLocation.City, checkIn: Date? = nil, checkOut: Date? = nil) {
        self.init(destination: city.hotelSearchName,
                  latitude: city.coordinate.lat, longitude: city.coordinate.lon,
                  checkIn: checkIn, checkOut: checkOut)
    }
}

extension CityLocation.City {
    /// The search-box text for hotels here. A campus name works on its own (the sites
    /// know "Duke University" as a landmark; adding "Durham, NC" made Booking.com match a
    /// hotel instead). A city gets its country so "Athens" isn't ambiguous.
    var hotelSearchName: String {
        if isCampus { return name }
        // Stamped calls Minneapolis "Minnesota"; a hotel site would search the whole state
        let cityName = self == .minnesota ? "Minneapolis" : name
        // .sar is "Special Administration Region"; Hong Kong needs no country
        guard country != .sar, country.rawValue != cityName else { return cityName }
        return "\(cityName), \(country.rawValue)"
    }
}

// MARK: - URL building

struct HotelLinkBuilder {
    var provider: HotelProvider
    var affiliateID: String?
    /// The calendar check-in and check-out days are read in. Trip dates are made with the
    /// device's calendar (local midnight), so the same calendar turns them back into the
    /// same day numbers; converting to the destination's time zone could shift a day.
    var calendar: Calendar

    /// The app's configuration. Tests pass their own provider and ID instead.
    init(provider: HotelProvider = HotelPartner.provider,
         affiliateID: String? = HotelPartner.affiliateID,
         calendar: Calendar = HotelLinkBuilder.defaultCalendar) {
        self.provider = provider
        self.affiliateID = affiliateID
        self.calendar = calendar
    }

    /// Gregorian, so "2026-11-10" is right even when the phone uses another calendar.
    static var defaultCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    /// The trimmed ID, when one is set and this provider's parameter is known.
    private var activeAffiliateID: String? {
        guard provider.affiliateTracking != nil,
              let id = affiliateID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !id.isEmpty else { return nil }
        return id
    }

    /// True when links carry an affiliate ID, so the "may earn a commission" note shows.
    var earnsCommission: Bool { activeAffiliateID != nil }

    /// The check-in and check-out days ("yyyy-MM-dd"), or nil when there's no check-in.
    /// A missing check-out, or one not after check-in, becomes the next day.
    func stayDates(for search: HotelSearch) -> (checkIn: String, checkOut: String)? {
        guard let checkInDate = search.checkIn else { return nil }
        let checkInDay = calendar.startOfDay(for: checkInDate)
        let requestedCheckOut = search.checkOut.map { calendar.startOfDay(for: $0) }
        let checkOutDay: Date
        if let requestedCheckOut, requestedCheckOut > checkInDay {
            checkOutDay = requestedCheckOut
        } else if let nextDay = calendar.date(byAdding: .day, value: 1, to: checkInDay) {
            checkOutDay = nextDay
        } else {
            return nil
        }
        return (dayString(checkInDay), dayString(checkOutDay))
    }

    private func dayString(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04ld-%02ld-%02ld", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The provider's public search URL for `search`.
    ///
    /// Booking.com:  searchresults.html?ss=<text>&latitude=<lat>&longitude=<lon>&checkin=yyyy-MM-dd&checkout=yyyy-MM-dd[&aid=<id>]
    /// Expedia / Hotels.com:  Hotel-Search?destination=<text>&latLong=<lat>,<lon>&startDate=yyyy-MM-dd&endDate=yyyy-MM-dd
    /// With an Expedia camref, that search link is wrapped in a Partnerize click link.
    func url(for search: HotelSearch) -> URL? {
        let destination = search.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        var items: [(String, String)] = []

        switch provider {
        case .booking:
            items.append(("ss", destination))
            if let latitude = search.latitude, let longitude = search.longitude {
                items.append(("latitude", Self.coordinateString(latitude)))
                items.append(("longitude", Self.coordinateString(longitude)))
            }
            if let dates = stayDates(for: search) {
                items.append(("checkin", dates.checkIn))
                items.append(("checkout", dates.checkOut))
            }
        case .expedia, .hotelsCom:
            items.append(("destination", destination))
            if let latitude = search.latitude, let longitude = search.longitude {
                items.append(("latLong", "\(Self.coordinateString(latitude)),\(Self.coordinateString(longitude))"))
            }
            if let dates = stayDates(for: search) {
                items.append(("startDate", dates.checkIn))
                items.append(("endDate", dates.checkOut))
            }
        }

        let id = activeAffiliateID
        if let id, case .queryParameter(let parameter) = provider.affiliateTracking {
            items.append((parameter, id))
        }

        // Encoded by hand: URLComponents leaves "+" and "&" alone in values,
        // which a site would read as a space or a new parameter.
        let query = items
            .map { "\(Self.encode($0.0))=\(Self.encode($0.1))" }
            .joined(separator: "&")
        let searchLink = "\(provider.searchEndpoint)?\(query)"

        if let id, provider.affiliateTracking == .partnerize {
            return URL(string: "https://prf.hn/click/camref:\(Self.encode(id))/destination:\(Self.encode(searchLink))")
        }
        return URL(string: searchLink)
    }

    /// Five decimals is about a metre, plenty for "hotels near here".
    private static func coordinateString(_ value: Double) -> String {
        String(format: "%.5f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    /// Percent-encodes everything except the characters RFC 3986 never reserves.
    static func encode(_ value: String) -> String {
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? value
    }
}

// MARK: - Button

/// "Find Hotels" (or a custom title like "Hotels near Duke"): opens the hotel site's search.
/// The caller styles it like the buttons around it (`.buttonStyle`, `.tint`).
/// Shows "Stamped! may earn a commission." under it only when an affiliate ID is set.
struct FindHotelsButton: View {
    let search: HotelSearch
    var title: String
    /// true: the in-app browser (Safari's own view, like Website on the map).
    /// false: hand the link to the system (Safari, or the hotel site's app if installed).
    var opensInApp = true
    /// Spoken by VoiceOver; defaults to "Find hotels in <destination> on <site>".
    var accessibilityText: String? = nil
    /// Stretches the label across the row, like the bordered buttons on the map's place card.
    var fillsWidth = false

    private let builder = HotelLinkBuilder()
    @State private var browserLink: BrowserLink?
    @Environment(\.openURL) private var openURL

    init(search: HotelSearch,
         title: String = NSLocalizedString("Find Hotels", comment: "Hotel link button: opens a hotel site's search for this place"),
         opensInApp: Bool = true,
         accessibilityText: String? = nil,
         fillsWidth: Bool = false) {
        self.search = search
        self.title = title
        self.opensInApp = opensInApp
        self.accessibilityText = accessibilityText
        self.fillsWidth = fillsWidth
    }

    var body: some View {
        if let url = builder.url(for: search) {
            VStack(alignment: fillsWidth ? .center : .leading, spacing: 4) {
                Button {
                    if opensInApp {
                        browserLink = BrowserLink(url: url)
                    } else {
                        openURL(url)
                    }
                } label: {
                    Label(title, systemImage: "bed.double.fill")
                        .frame(maxWidth: fillsWidth ? .infinity : nil)
                        .padding(.vertical, fillsWidth ? 6 : 0)
                }
                .accessibilityLabel(accessibilityText ?? String(
                    format: NSLocalizedString("Find hotels in %1$@ on %2$@", comment: "Hotel link button, VoiceOver: e.g. \"Find hotels in Duke University on Booking.com\""),
                    search.destination, builder.provider.displayName
                ))
                .accessibilityHint(NSLocalizedString("Opens the hotel website. Stamped! doesn't handle bookings or payments.", comment: "Hotel link button, VoiceOver hint"))

                if builder.earnsCommission {
                    HotelCommissionNote()
                }
            }
            .inAppBrowser(item: $browserLink)
        }
    }
}

/// The affiliate disclosure. Only shown when links carry an affiliate ID.
struct HotelCommissionNote: View {
    var body: some View {
        Text(NSLocalizedString("Stamped! may earn a commission.", comment: "Hotel links: disclosure shown under hotel buttons when an affiliate ID is configured"))
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}
