protocol ClimateService: Sendable {
    func climateClassification(for city: City) -> ClimateClassification
}

/// Latitude-based climate classification.
///
/// - Tropical: 0–15°
/// - Arid: 15–30°
/// - Temperate: >30°
struct LiveClimateService: ClimateService {
    func climateClassification(for city: City) -> ClimateClassification {
        let absLat = abs(city.latitude)
        switch absLat {
        case 0..<15: return .tropical
        case 15..<30: return .arid
        default: return .temperate
        }
    }
}
