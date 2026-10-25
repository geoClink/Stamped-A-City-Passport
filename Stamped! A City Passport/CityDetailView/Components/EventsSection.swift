//
//  EventsSection.swift
//  Stamped! A City Passport
//

import SwiftUI

struct EventsSection: View {
    @ObservedObject var service: TicketmasterService
    let isHighContrast: Bool
    var brandColor: Color { isHighContrast ? .primary : Color.adventureOrange }

    @State private var selectedCategory: TicketmasterEvent.EventCategory? = nil

    private var presentCategories: [TicketmasterEvent.EventCategory] {
        let cats = service.events.map { $0.category }
        var seen = Set<String>()
        return cats.filter { seen.insert($0.rawValue).inserted }
    }

    private var filteredEvents: [TicketmasterEvent] {
        guard let cat = selectedCategory else { return service.events }
        return service.events.filter { $0.category == cat }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            DSSectionHeader("Upcoming Events", systemImage: "ticket.fill", isHighContrast: isHighContrast)
                .dsPageMargin()

            // Unified card container
            VStack(alignment: .leading, spacing: 0) {
                if service.isLoading {
                    HStack(spacing: DS.Space.s) {
                        ProgressView().scaleEffect(0.7)
                        Text("Finding events…")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(DS.Space.l)
                } else if service.events.isEmpty {
                    HStack(spacing: DS.Space.m) {
                        Image(systemName: "ticket.fill")
                            .font(.title2)
                            .foregroundColor(.secondary.opacity(0.5))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No Upcoming Events")
                                .font(.subheadline).fontWeight(.semibold)
                            Text("Ticketmaster coverage varies by city.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(DS.Space.l)
                } else {
                    // Filter chips
                    if presentCategories.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DS.Space.s) {
                                FilterChip(
                                    label: "All",
                                    icon: nil,
                                    isSelected: selectedCategory == nil,
                                    color: brandColor
                                ) { selectedCategory = nil }

                                ForEach(presentCategories, id: \.rawValue) { cat in
                                    FilterChip(
                                        label: cat.rawValue,
                                        icon: cat.icon,
                                        isSelected: selectedCategory == cat,
                                        color: cat.tint(brandColor: brandColor, isHighContrast: isHighContrast)
                                    ) { selectedCategory = (selectedCategory == cat) ? nil : cat }
                                }
                            }
                            .padding(.horizontal, DS.Space.l)
                        }
                        .padding(.top, DS.Space.l)

                        Divider().padding(.horizontal, DS.Space.l).padding(.top, DS.Space.m)
                    }

                    let displayed = filteredEvents
                    if displayed.isEmpty {
                        Text("No \(selectedCategory?.rawValue ?? "") events found")
                            .font(.caption).foregroundColor(.secondary)
                            .padding(DS.Space.l)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: DS.Space.m) {
                                ForEach(displayed) { event in
                                    EventCard(event: event, brandColor: brandColor, isHighContrast: isHighContrast)
                                }
                            }
                            .padding(DS.Space.l)
                        }
                    }
                }
            }
            .dsCard(padding: 0, isHighContrast: isHighContrast)
            .dsPageMargin()

            Text("Event data from Ticketmaster. Stamped is not responsible for event cancellations.")
                .font(.caption2)
                .foregroundColor(isHighContrast ? .primary : .secondary)
                .dsPageMargin()
        }
    }
}

// MARK: - Category color

private extension TicketmasterEvent.EventCategory {
    /// Event categories keep their own semantic colors; high contrast drops the color coding.
    func tint(brandColor: Color, isHighContrast: Bool) -> Color {
        if isHighContrast { return .primary }
        switch self {
        case .music:  return .purple
        case .sports: return .blue
        case .arts:   return .teal  // pink is reserved for Want to Visit
        case .film:   return .indigo
        case .family: return .green
        default:      return brandColor
        }
    }
}

// MARK: - Filter chip

private struct FilterChip: View {
    let label: String
    let icon: String?
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.xs) {
                if let icon {
                    Image(systemName: icon).font(.caption.weight(.medium))
                }
                Text(label).font(.caption.bold()).lineLimit(1)
            }
            // In high contrast the fill is .primary, so the label flips to the background color
            .foregroundColor(isSelected ? (color == .primary ? Color(UIColor.systemBackground) : .white) : color)
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, DS.Space.s)
            .background(Capsule().fill(isSelected ? color : color.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .accessibilityLabel(isSelected ? "\(label), selected" : label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Event card (horizontal scroll)

private struct EventCard: View {
    let event: TicketmasterEvent
    let brandColor: Color
    let isHighContrast: Bool

    @ScaledMetric(relativeTo: .subheadline) private var cardWidth: CGFloat = 220
    @ScaledMetric(relativeTo: .subheadline) private var badgeSize: CGFloat = 36

    private var accentColor: Color {
        event.category.tint(brandColor: brandColor, isHighContrast: isHighContrast)
    }

    var body: some View {
        Group {
            if let url = event.ticketURL {
                Link(destination: url) { cardContent }
                    .simultaneousGesture(TapGesture().onEnded {
                        HapticManager.shared.trigger(.selection)
                    })
            } else {
                cardContent
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(event.ticketURL != nil ? "Opens Ticketmaster to buy tickets" : "")
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            // Top row: icon badge + price
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                        .fill(accentColor.opacity(0.15))
                        .frame(width: badgeSize, height: badgeSize)
                    Image(systemName: event.category.icon)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(accentColor)
                }

                Spacer()

                if let price = event.priceRange {
                    Text(price)
                        .font(.caption.bold())
                        .foregroundColor(accentColor)
                        .lineLimit(1)
                        .padding(.horizontal, DS.Space.s)
                        .padding(.vertical, DS.Space.xs)
                        .background(Capsule().fill(accentColor.opacity(0.12)))
                }
            }

            // Event name — up to 3 lines so long names are readable
            Text(event.name)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            // Date / time / venue
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                if !event.date.isEmpty {
                    Label(event.date + (event.time.isEmpty ? "" : " · \(event.time)"),
                          systemImage: "calendar")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if !event.venueName.isEmpty {
                    Label(event.venueName, systemImage: "mappin")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            // Buy button stripe at bottom
            if event.ticketURL != nil {
                HStack {
                    Text("Get Tickets")
                        .font(.caption.bold())
                        .foregroundColor(accentColor)
                    Image(systemName: "arrow.up.right")
                        .font(.caption2.bold())
                        .foregroundColor(accentColor)
                }
            }
        }
        .padding(DS.Space.m)
        .frame(width: cardWidth, alignment: .leading)
        // A card inside the section card: one step lighter/darker and the small radius
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                .fill(isHighContrast ? Color(UIColor.systemBackground) : Color(UIColor.tertiarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 2)
        )
    }

    private var accessibilityLabel: String {
        var parts = [event.name, event.category.rawValue]
        if !event.date.isEmpty { parts.append(event.date) }
        if !event.time.isEmpty { parts.append("at \(event.time)") }
        if !event.venueName.isEmpty { parts.append("at \(event.venueName)") }
        if let price = event.priceRange { parts.append(price) }
        return parts.joined(separator: ", ")
    }
}
