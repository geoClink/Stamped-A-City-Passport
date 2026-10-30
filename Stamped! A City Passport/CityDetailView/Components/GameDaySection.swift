//
//  GameDaySection.swift
//  Stamped! A City Passport
//
//  The Game Day section on a campus page: upcoming home games (from the same
//  Ticketmaster/SeatGeek search as Upcoming Events), photos of the stadium and arenas
//  with their Commons credit, NCAA team titles, and a link to the official athletics
//  site for live scores. Data: CampusAthletics.json and GameDayService.
//  School colors only: no team logos, mascots or wordmarks.
//

import SwiftUI

struct GameDaySection: View {
    let campus: CityLocation.City
    var isHighContrast: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var homeGames: [TicketmasterEvent] = []
    @State private var isLoading = true
    @ScaledMetric(relativeTo: .subheadline) private var photoWidth: CGFloat = 240
    @ScaledMetric(relativeTo: .subheadline) private var photoHeight: CGFloat = 150

    /// The school's color, like the campus stamp; orange when it has none
    private var accent: Color {
        isHighContrast ? .primary : (campus.stampColor(darkMode: colorScheme == .dark) ?? DS.Palette.accent)
    }

    private var athletics: CampusAthletics? { campus.athletics }
    private var photoVenues: [GameDayVenue] { campus.gameDayVenues.filter { $0.photo != nil } }

    var body: some View {
        if athletics != nil {
            // Fixed content (link, photos, titles) shows at once; home games join when they load
            content
                .task(id: campus.id) { await loadGames() }
        } else if !homeGames.isEmpty {
            content
        } else if isLoading && !campus.gameDayVenues.isEmpty {
            // A `.task` on an empty view never runs, so loading hangs off this
            // invisible placeholder; it goes away once the load is done
            Color.clear
                .frame(height: 0)
                .accessibilityHidden(true)
                .task(id: campus.id) { await loadGames() }
        }
        // Nothing known and nothing found: render nothing
    }

    private func loadGames() async {
        let games = await GameDayService.shared.homeGames(for: campus)
        withAnimation(.easeIn(duration: 0.2)) {
            homeGames = games
            isLoading = false
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader("GAME DAY", systemImage: "sportscourt.fill", isHighContrast: isHighContrast)
                .dsPageMargin()

            if !homeGames.isEmpty {
                homeGamesCard
            }

            if !photoVenues.isEmpty {
                venuePhotos
            }

            if let championships = athletics?.championships, !championships.titles.isEmpty {
                championshipsCard(championships)
            }

            if let url = athletics?.athleticsURL {
                Link(destination: url) {
                    Label(NSLocalizedString("Live scores & schedule", comment: "Game Day: link to the school's official athletics website"), systemImage: "arrow.up.right.square")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(accent)
                }
                .accessibilityHint(NSLocalizedString("Opens the official athletics website", comment: "Game Day: VoiceOver hint for the athletics website link"))
                .dsPageMargin()
            }
        }
        .transition(.opacity)
    }

    // MARK: - Home games

    private var homeGamesCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text(NSLocalizedString("Upcoming home games", comment: "Game Day: heading over the list of home games"))
                .font(.headline)
                .dsPageMargin()

            VStack(spacing: 0) {
                ForEach(homeGames) { game in
                    gameRow(game)
                    if game.id != homeGames.last?.id {
                        Divider().padding(.leading, DS.Space.l)
                            .accessibilityHidden(true)
                    }
                }
            }
            .dsCard(padding: 0, isHighContrast: isHighContrast)
            .dsPageMargin()

            // The same notes as Upcoming Events: where the data comes from, and the commission
            Text(homeGames.contains { $0.sellerName == "SeatGeek" }
                 ? LocalizedStringKey("Event data from Ticketmaster and SeatGeek. Stamped is not responsible for event cancellations.")
                 : "Event data from Ticketmaster. Stamped is not responsible for event cancellations.")
                .font(.caption2)
                .foregroundColor(isHighContrast ? .primary : .secondary)
                .dsPageMargin()

            if SeatGeekPartner.affiliateID != nil, homeGames.contains(where: { $0.sellerName == "SeatGeek" }) {
                Text(NSLocalizedString("Stamped! may earn a commission.", comment: "Hotel links: disclosure shown under hotel buttons when an affiliate ID is configured"))
                    .font(.caption2)
                    .foregroundColor(isHighContrast ? .primary : .secondary)
                    .dsPageMargin()
            }
        }
    }

    @ViewBuilder
    private func gameRow(_ game: TicketmasterEvent) -> some View {
        // "Spartans vs. Huskies" with "Football" on its own line, not the sport on both teams
        let display = GameDayService.displayTitle(game.name)
        let row = HStack(alignment: .top, spacing: DS.Space.m) {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                if let sport = display.sport {
                    Text(sport.localizedUppercase)
                        .font(.caption2.monospaced().weight(.semibold))
                        .foregroundColor(isHighContrast ? .primary : accent)
                }
                Text(display.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if !game.date.isEmpty {
                    // Sellers leave the time blank until kickoff is set
                    Label(game.date + " · " + (game.time.isEmpty ? NSLocalizedString("Time TBA", comment: "Game Day: a game whose start time isn't announced yet") : game.time),
                          systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(isHighContrast ? .primary : .secondary)
                }
                if !game.venueName.isEmpty {
                    Label(game.venueName, systemImage: "mappin")
                        .font(.caption)
                        .foregroundColor(isHighContrast ? .primary : .secondary)
                }
            }
            Spacer(minLength: 0)
            if game.ticketURL != nil {
                HStack(spacing: 2) {
                    Text("Get Tickets")
                    Image(systemName: "arrow.up.right")
                }
                .font(.caption.bold())
                .foregroundColor(accent)
            }
        }
        .padding(DS.Space.l)
        .contentShape(Rectangle())

        if let url = game.ticketURL {
            Link(destination: url) { row }
                .simultaneousGesture(TapGesture().onEnded { HapticManager.shared.trigger(.selection) })
                .accessibilityElement(children: .combine)
                .accessibilityHint("Opens \(game.sellerName) to buy tickets")
        } else {
            row.accessibilityElement(children: .combine)
        }
    }

    // MARK: - Venue photos

    private var venuePhotos: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: DS.Space.m) {
                ForEach(photoVenues) { venue in
                    if let photo = venue.photo {
                        venuePhoto(venue, photo: photo)
                    }
                }
            }
            .padding(.horizontal, DS.Space.page)
        }
    }

    private func venuePhoto(_ venue: GameDayVenue, photo: CampusAthletics.VenuePhoto) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            // The size comes from this clear frame, so a wide photo can't stretch the card
            Color.clear
                .frame(width: photoWidth, height: photoHeight)
                .overlay {
                    AsyncImage(url: photo.imageURL) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            DS.Palette.cardBackground
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                        .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
                )
                .accessibilityLabel(String(format: NSLocalizedString("Photo of %@", comment: "Game Day: VoiceOver label for a stadium or arena photo"), venue.name))

            Text(venue.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // The photo's credit, as its licence asks; opens the file on Wikimedia Commons
            Link(destination: photo.filePageURL) {
                Text(String(format: NSLocalizedString("Photo: %@, %@", comment: "Game Day: photo credit, e.g. Photo: Jeffness, CC BY-SA 2.5"), photo.author, photo.license))
                    .font(.caption2)
                    .foregroundColor(isHighContrast ? .primary : .secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .accessibilityHint(NSLocalizedString("Opens the photo on Wikimedia Commons", comment: "Game Day: VoiceOver hint for a photo credit"))
        }
        .frame(width: photoWidth, alignment: .leading)
    }

    // MARK: - Championships

    private func championshipsCard(_ championships: CampusAthletics.Championships) -> some View {
        let total = championships.titles.reduce(0) { $0 + $1.years.count }
        return VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(NSLocalizedString("NCAA team championships", comment: "Game Day: heading over the list of national titles"))
                    .font(.headline)
                Spacer(minLength: DS.Space.s)
                Text("\(total)")
                    .font(.headline.monospacedDigit())
                    .foregroundColor(accent)
                    .accessibilityLabel(String(format: NSLocalizedString("%d titles", comment: "Game Day: VoiceOver count of national titles"), total))
            }
            .dsPageMargin()

            VStack(alignment: .leading, spacing: DS.Space.m) {
                ForEach(championships.titles, id: \.self) { title in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString(title.sport, comment: "Game Day: a sport with national titles"))
                            .font(.subheadline.weight(.semibold))
                        Text(yearsText(title))
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(isHighContrast ? .primary : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
            .dsCard(isHighContrast: isHighContrast)
            .dsPageMargin()

            Link(destination: championships.sourceURL) {
                Text(String(format: NSLocalizedString("Source: %@", comment: "Game Day: where the list of national titles comes from"), championships.source))
                    .font(.caption2)
                    .foregroundColor(isHighContrast ? .primary : .secondary)
                    .multilineTextAlignment(.leading)
            }
            .dsPageMargin()
        }
    }

    /// "1967 (shared), 1968 (shared)": years as plain text, so 1979 never reads "1,979"
    private func yearsText(_ title: CampusAthletics.Title) -> String {
        let shared = Set(title.sharedYears ?? [])
        return title.years.map { year in
            shared.contains(year)
                ? String(format: NSLocalizedString("%@ (shared)", comment: "Game Day: a national title shared with another school, e.g. 1967 (shared)"), String(year))
                : String(year)
        }
        .joined(separator: ", ")
    }
}
