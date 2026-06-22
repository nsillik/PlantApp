import SwiftUI

struct CareSheetView: View {
    let careSheet: CareSheet

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionCard(icon: "drop", title: String(localized: "Water"), content: careSheet.water)
            SectionCard(icon: "sun.max", title: String(localized: "Light"), content: careSheet.light)
            SectionCard(icon: "leaf", title: String(localized: "Soil"), content: careSheet.soil)
            SectionCard(icon: "humidity", title: String(localized: "Humidity"), content: careSheet.humidity)
            SectionCard(icon: "exclamationmark.triangle", title: String(localized: "Toxicity"), content: careSheet.toxicity)
            SectionCard(icon: "wrench", title: String(localized: "Common Problems"), content: careSheet.commonProblems)
        }
    }
}

private struct SectionCard: View {
    let icon: String
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
