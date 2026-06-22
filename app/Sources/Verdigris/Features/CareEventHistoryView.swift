import SwiftUI

struct CareEventHistoryView: View {
    let events: [CareEvent]

    var body: some View {
        ForEach(events) { event in
            HStack(spacing: 12) {
                Image(systemName: icon(for: event.eventType))
                    .font(.title3)
                    .foregroundStyle(color(for: event.eventType))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label(for: event.eventType))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(event.timestamp, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let notes = event.notes {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let photo = event.photoData, let uiImage = UIImage(data: photo) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func icon(for type: CareEventType) -> String {
        switch type {
        case .watered: "drop.fill"
        case .fertilized: "leaf.arrow.circlepath"
        case .pruned: "scissors"
        case .repotted: "tray.full"
        }
    }

    private func color(for type: CareEventType) -> Color {
        switch type {
        case .watered: .blue
        case .fertilized: .green
        case .pruned: .orange
        case .repotted: .brown
        }
    }

    private func label(for type: CareEventType) -> String {
        switch type {
        case .watered: String(localized: "Watered")
        case .fertilized: String(localized: "Fertilized")
        case .pruned: String(localized: "Pruned")
        case .repotted: String(localized: "Repotted")
        }
    }
}
