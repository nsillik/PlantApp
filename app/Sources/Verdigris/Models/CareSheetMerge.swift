import Foundation

func generateCareSheet(
    species: PlantSpecies,
    user: UserProfile,
    light: LightPlacement,
    humidity: HumidityPlacement,
    season: Season
) -> CareSheet {
    let water = waterInstruction(species: species, light: light, humidity: humidity, season: season)
    let lightText = lightInstruction(species: species, light: light)
    let soil = soilInstruction(species: species)
    let humidityText = humidityInstruction(humidity: humidity, species: species)
    let toxicity = toxicityText(species: species)
    let problems = commonProblemsText(species: species, light: light, humidity: humidity, season: season)

    return CareSheet(
        water: water,
        light: lightText,
        soil: soil,
        humidity: humidityText,
        toxicity: toxicity,
        commonProblems: problems
    )
}

private func waterInstruction(species: PlantSpecies, light: LightPlacement, humidity: HumidityPlacement, season: Season) -> String {
    let base = species.wateringInterval
    var adjustment = 0.0

    switch light {
    case .directSouth: adjustment -= 2
    case .directEastWest: adjustment -= 1
    case .indirect: adjustment += 1
    }

    switch humidity {
    case .dry: adjustment -= 1
    case .normal: break
    case .wet: adjustment += 1
    }

    switch season {
    case .summer: adjustment -= 1
    case .winter: adjustment += 2
    case .spring, .fall: break
    }

    let adjusted = max(1, Double(base) + adjustment)
    let lower = Int(adjusted.rounded(.down))
    let upper = Int((adjusted + 1).rounded(.down))

    if lower == upper {
        return String(localized: "Water every \(lower) days")
    }
    return String(localized: "Water every \(lower)–\(upper) days")
}

private func lightInstruction(species: PlantSpecies, light: LightPlacement) -> String {
    switch light {
    case .directSouth:
        return String(localized: "Your south-facing window is perfect for this plant.")
    case .directEastWest:
        return String(localized: "East or west exposure works well — just avoid intense midday sun.")
    case .indirect:
        if let needs = species.lightNeeds?.lowercased(), needs.contains("low") {
            return String(localized: "Indirect light is ideal — this plant tolerates low light well.")
        }
        return String(localized: "Current placement may be too dim — consider moving closer to a window.")
    }
}

private func soilInstruction(species: PlantSpecies) -> String {
    if let soil = species.soilType {
        return String(localized: "Repot in \(soil.lowercased())")
    }
    return String(localized: "Use a well-draining potting mix")
}

private func humidityInstruction(humidity: HumidityPlacement, species: PlantSpecies) -> String {
    switch humidity {
    case .dry:
        return String(localized: "This dry room may cause brown tips — consider a pebble tray or humidifier.")
    case .normal:
        return String(localized: "Room humidity looks adequate for this plant.")
    case .wet:
        return String(localized: "High humidity is great — many plants thrive in these conditions.")
    }
}

private func toxicityText(species: PlantSpecies) -> String {
    guard let toxicity = species.toxicity else {
        return String(localized: "No toxicity information available.")
    }
    return String(localized: "Toxicity: \(toxicity)")
}

private func commonProblemsText(species: PlantSpecies, light: LightPlacement, humidity: HumidityPlacement, season: Season) -> String {
    guard let issues = species.commonIssues, !issues.isEmpty else {
        return String(localized: "No common issues reported for this species.")
    }

    var relevant = issues

    if humidity == .dry {
        relevant = relevant.filter { $0 != "root rot" }
    }

    if light == .indirect {
        relevant = relevant.filter { $0 != "sunburn" }
    }

    if season == .winter {
        if !relevant.contains(where: { $0.lowercased().contains("overwatering") }) {
            relevant.append("overwatering risk")
        }
    }

    let formatted = relevant.joined(separator: ", ")
    return String(localized: "Watch for: \(formatted)")
}
