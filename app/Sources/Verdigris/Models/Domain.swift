import Foundation

/// The user's profile, used to derive climate-aware care recommendations.
struct UserProfile: Identifiable, Sendable, Codable {
    let id: UUID
    /// City name for climate lookup.
    var city: String
    /// Geographic latitude in decimal degrees.
    var latitude: Double
    /// Geographic longitude in decimal degrees.
    var longitude: Double
    /// Climate zone derived from the user's location.
    var climateClassification: ClimateClassification
}

/// Broad climate classification for care-schedule adjustments.
enum ClimateClassification: String, Sendable, Codable {
    /// Moderate climate with distinct seasons.
    case temperate
    /// Warm, humid climate year-round.
    case tropical
    /// Dry, low-humidity climate.
    case arid
}

/// Reference data describing care requirements for a plant species.
struct PlantSpecies: Identifiable, Sendable, Codable {
    let id: UUID
    /// Everyday name, e.g. "Monstera".
    var commonName: String
    /// Binomial name, e.g. "Monstera deliciosa".
    var scientificName: String?
    /// Preferred light conditions.
    var lightNeeds: String?
    /// Ideal interval between waterings, in days.
    var wateringInterval: Int
    /// Preferred soil mix description.
    var soilType: String?
    /// Preferred humidity level description.
    var humidityRange: String?
    /// Pet or child safety information.
    var toxicity: String?
    /// Growth pattern, e.g. trailing, upright, rosette.
    var growthHabit: String?
    /// Frequent problems associated with this species.
    var commonIssues: [String]?
    /// URLs to reference images for this species.
    var imageURLs: [String]?
}

/// A plant the user owns, linked to a reference species.
struct Plant: Identifiable, Sendable, Codable {
    let id: UUID
    /// User-assigned display name, e.g. "Living Room Fern".
    var name: String
    /// The date the plant was added to the app.
    var dateAdded: Date
    /// References the `PlantSpecies` this plant belongs to.
    var speciesID: UUID
    /// Where the plant is placed relative to natural light.
    var placementLight: LightPlacement?
    /// Where the plant is placed relative to ambient humidity.
    var placementHumidity: HumidityPlacement?
}

/// Light exposure level at the plant's location.
enum LightPlacement: String, Sendable, Codable {
    /// No direct sunlight reaches the plant.
    case indirect
    /// Strong, direct light from a south-facing window (Northern Hemisphere).
    case directSouth
    /// Moderate direct light from an east- or west-facing window.
    case directEastWest
}

/// Ambient humidity level at the plant's location.
enum HumidityPlacement: String, Sendable, Codable {
    /// Low-humidity area, e.g. near a heater or vent.
    case dry
    /// Typical indoor humidity.
    case normal
    /// High-humidity area, e.g. bathroom or kitchen.
    case wet
}

/// A logged care action performed on a plant.
struct CareEvent: Identifiable, Sendable, Codable {
    let id: UUID
    /// The plant that received care.
    var plantID: UUID
    /// The type of care performed.
    var eventType: CareEventType
    /// When the care occurred.
    var timestamp: Date
    /// Optional photo captured during the care event.
    var photoData: Data?
}

/// Kinds of care actions that can be logged.
enum CareEventType: String, Sendable, Codable {
    case watered
    case fertilized
    case pruned
    case repotted
}

/// Tracks the most recent care dates for a plant to drive reminders.
struct CareSchedule: Identifiable, Sendable, Codable {
    let id: UUID
    /// The plant this schedule belongs to.
    var plantID: UUID
    var lastWatered: Date?
    var lastFertilized: Date?
    var lastPruned: Date?
    var lastRepotted: Date?
    /// Number of days of flexibility before a reminder is considered overdue.
    var adherenceOffset: Int
}

/// A growth or health observation logged for a plant.
struct JournalEntry: Identifiable, Sendable, Codable {
    let id: UUID
    /// The plant being observed.
    var plantID: UUID
    /// The date of the observation.
    var date: Date
    /// Overall health rating from 1 (worst) to 10 (best).
    var healthScore: Int
    /// Leaf count at the time of observation.
    var leafCount: Int
    /// Plant height in centimeters.
    var height: Double
    /// Freeform observation notes.
    var notes: String?
    /// Optional photo taken during the observation.
    var photoData: Data?
}

/// An environmental data point, sourced from device sensors or weather APIs.
struct EnvironmentalReading: Identifiable, Sendable, Codable {
    let id: UUID
    /// When the reading was captured.
    var date: Date
    /// Temperature in degrees Celsius.
    var temperature: Double
    /// Relative humidity as a percentage (0–100).
    var humidity: Double
    /// Hours of daylight for the given date and location.
    var daylightHours: Double
}
