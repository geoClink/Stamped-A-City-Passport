import SwiftUI

struct SoundCreditsView: View {

    private struct SoundCredit: Identifiable {
        let id = UUID()
        let role: String
        let title: String
        let author: String
        let license: String
        let url: String
    }

    private let credits: [SoundCredit] = [
        .init(role:    "City Ambience",
              title:   "Small City Ambience",
              author:  "felix.blume",
              license: "CC BY 4.0",
              url:     "freesound.org/people/felix.blume/sounds/705049"),
        .init(role:    "Football Crowd (Ford Field)",
              title:   "Football Match Crowd Cheer Ambience",
              author:  "Dan_AudioFile",
              license: "CC BY 4.0",
              url:     "freesound.org/people/Dan_AudioFile/sounds/654083"),
        .init(role:    "Rain",
              title:   "Rain Loop",
              author:  "qubodup",
              license: "CC BY 4.0",
              url:     "freesound.org/people/qubodup/sounds/212580"),
        .init(role:    "Baseball Crowd (Comerica Park)",
              title:   "MLB Stadium Crowd",
              author:  "bmadore",
              license: "CC0 — Public Domain",
              url:     "freesound.org/s/691975"),
        .init(role:    "Night Crickets",
              title:   "Night Crickets Ambience",
              author:  "OwlStorm",
              license: "CC0 — Public Domain",
              url:     "freesound.org/people/OwlStorm/sounds/320145"),
    ]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(credits) { credit in
                VStack(alignment: .leading, spacing: 4) {
                    Text(credit.role)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text("\"\(credit.title)\"")
                        .font(.subheadline.bold())
                    Text("by \(credit.author)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(credit.license)
                            .font(.caption)
                            .foregroundStyle(credit.license.hasPrefix("CC0") ? .green : .orange)
                        Spacer()
                        Text(credit.url)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.top, 2)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Sound Credits")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
