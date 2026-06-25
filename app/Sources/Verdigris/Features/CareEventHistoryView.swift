import SwiftUI

struct CareEventHistoryView: View {
    let events: [CareEvent]

    var body: some View {
        ForEach(events) { event in
            HStack(spacing: 12) {
                Image(systemName: event.eventType.systemImage)
                    .font(.title3)
                    .foregroundStyle(event.eventType.tint)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.eventType.localizedLabel)
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
}
