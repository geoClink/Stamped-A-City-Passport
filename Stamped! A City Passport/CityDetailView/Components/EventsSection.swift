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
        VStack(alignment: .leading, spacing: 12) {
            Label("UPCOMING EVENTS", systemImage: "ticket.fill")
                .font(.system(.caption, design: .default))
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .kerning(1.2)
                .padding(.horizontal)

            // Unified card container
            VStack(alignment: .leading, spacing: 0) {
                if service.isLoading {
                    HStack(spacing: 10) {
                        ProgressView().scaleEffect(0.7)
                        Text("Finding events…")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(16)
                } else if service.events.isEmpty {
                    HStack(spacing: 12) {
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
                    .padding(16)
                } else {
                    // Filter chips
                    if presentCategories.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
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
                                        color: categoryColor(cat)
                                    ) { selectedCategory = (selectedCategory == cat) ? nil : cat }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 14)

                        Divider().padding(.horizontal, 16).padding(.top, 12)
                    }

                    let displayed = filteredEvents
                    if displayed.isEmpty {
                        Text("No \(selectedCategory?.rawValue ?? "") events found")
                            .font(.caption).foregroundColor(.secondary)
                            .padding(16)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(displayed) { event in
                                    EventCard(event: event, brandColor: brandColor)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                    }
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)

            Text("Event data from Ticketmaster. Stamped is not responsible for event cancellations.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }

    private func categoryColor(_ cat: TicketmasterEvent.EventCategory) -> Color {
        switch cat {
        case .music:  return .purple
        case .sports: return .blue
        case .arts:   return .pink
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
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon).font(.caption.weight(.medium))
                }
                Text(label).font(.caption.bold())
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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

    private var accentColor: Color {
        switch event.category {
        case .music:  return .purple
        case .sports: return .blue
        case .arts:   return .pink
        case .film:   return .indigo
        case .family: return .green
        default:      return brandColor
        }
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
        VStack(alignment: .leading, spacing: 10) {
            // Top row: icon badge + price
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: event.category.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(accentColor)
                }

                Spacer()

                if let price = event.priceRange {
                    Text(price)
                        .font(.caption.bold())
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
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
            VStack(alignment: .leading, spacing: 3) {
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
        .padding(14)
        .frame(width: 220, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
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
