import Foundation
import struct SwiftUI.Color

/// The user's profile, used to derive climate-aware care recommendations.
struct UserProfile: Identifiable, Sendable, Codable {
    let id: UUID
    var city: String
    var latitude: Double
    var longitude: Double
    var climateClassification: ClimateClassification
}

/// Broad climate classification for care-schedule adjustments.
enum ClimateClassification: String, Sendable, Codable {
    case temperate
    case tropical
    case arid

    var localizedLabel: String {
        switch self {
        case .temperate: String(localized: "Temperate")
        case .tropical: String(localized: "Tropical")
        case .arid: String(localized: "Arid")
        }
    }

    var localizedClimateLabel: String {
        String(localized: "climate.label.\(rawValue)")
    }
}

/// Wraps localized common names for a plant species.
struct PlantName: Sendable, Codable, Equatable {
    var commonNamesLocalized: [String: String]

    var localizedName: String {
        let preferredLocale = Locale.current.language.languageCode?.identifier ?? "en"
        return commonNamesLocalized[preferredLocale]
            ?? commonNamesLocalized["en"]
            ?? commonNamesLocalized.values.first
            ?? "Unknown"
    }

    init(commonNamesLocalized: [String: String]) {
        self.commonNamesLocalized = commonNamesLocalized
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let localized = try? container.decode([String: String].self, forKey: .commonNamesLocalized) {
            self.commonNamesLocalized = localized
        } else if let single = try? container.decode(String.self, forKey: .commonName) {
            self.commonNamesLocalized = ["en": single]
        } else {
            self.commonNamesLocalized = ["en": "Unknown"]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(commonNamesLocalized, forKey: .commonNamesLocalized)
    }

    private enum CodingKeys: String, CodingKey {
        case commonName
        case commonNamesLocalized
    }
}

/// Season derived from current month and hemisphere.
enum Season: String, Sendable, Codable, CaseIterable {
    case spring
    case summer
    case fall
    case winter

    static func current(latitude: Double) -> Season {
        let month = Calendar.current.component(.month, from: Date())
        let isNorthern = latitude >= 0
        switch month {
        case 3...5: return isNorthern ? .spring : .fall
        case 6...8: return isNorthern ? .summer : .winter
        case 9...11: return isNorthern ? .fall : .spring
        default: return isNorthern ? .winter : .summer
        }
    }
}

/// Personalized care instructions output by the merge function.
struct CareSheet: Sendable, Codable, Equatable {
    var water: String
    var light: String
    var soil: String
    var humidity: String
    var toxicity: String
    var commonProblems: String
}

/// Reference data describing care requirements for a plant species.
struct PlantSpecies: Identifiable, Sendable, Codable, Equatable {
    let id: UUID
    var name: PlantName
    var scientificName: String?
    var lightNeeds: String?
    var wateringInterval: Int
    var fertilizingInterval: Int
    var pruningInterval: Int
    var repottingInterval: Int
    var soilType: String?
    var humidityRange: String?
    var toxicity: String?
    var growthHabit: String?
    var commonIssues: [String]?
    var imageURLs: [String]?

    init(
        id: UUID,
        name: PlantName,
        scientificName: String? = nil,
        lightNeeds: String? = nil,
        wateringInterval: Int,
        fertilizingInterval: Int = 30,
        pruningInterval: Int = 90,
        repottingInterval: Int = 365,
        soilType: String? = nil,
        humidityRange: String? = nil,
        toxicity: String? = nil,
        growthHabit: String? = nil,
        commonIssues: [String]? = nil,
        imageURLs: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.scientificName = scientificName
        self.lightNeeds = lightNeeds
        self.wateringInterval = wateringInterval
        self.fertilizingInterval = fertilizingInterval
        self.pruningInterval = pruningInterval
        self.repottingInterval = repottingInterval
        self.soilType = soilType
        self.humidityRange = humidityRange
        self.toxicity = toxicity
        self.growthHabit = growthHabit
        self.commonIssues = commonIssues
        self.imageURLs = imageURLs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try PlantName(from: decoder)
        scientificName = try container.decodeIfPresent(String.self, forKey: .scientificName)
        lightNeeds = try container.decodeIfPresent(String.self, forKey: .lightNeeds)
        wateringInterval = try container.decode(Int.self, forKey: .wateringInterval)
        fertilizingInterval = try container.decodeIfPresent(Int.self, forKey: .fertilizingInterval) ?? 30
        pruningInterval = try container.decodeIfPresent(Int.self, forKey: .pruningInterval) ?? 90
        repottingInterval = try container.decodeIfPresent(Int.self, forKey: .repottingInterval) ?? 365
        soilType = try container.decodeIfPresent(String.self, forKey: .soilType)
        humidityRange = try container.decodeIfPresent(String.self, forKey: .humidityRange)
        toxicity = try container.decodeIfPresent(String.self, forKey: .toxicity)
        growthHabit = try container.decodeIfPresent(String.self, forKey: .growthHabit)
        commonIssues = try container.decodeIfPresent([String].self, forKey: .commonIssues)
        imageURLs = try container.decodeIfPresent([String].self, forKey: .imageURLs)
    }

    private enum CodingKeys: String, CodingKey {
        case id, scientificName, lightNeeds, wateringInterval, fertilizingInterval, pruningInterval, repottingInterval, soilType, humidityRange, toxicity, growthHabit, commonIssues, imageURLs
    }
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
enum LightPlacement: String, Sendable, Codable, CaseIterable {
    case indirect
    case directSouth
    case directEastWest

    var label: String {
        switch self {
        case .indirect: String(localized: "Indirect")
        case .directSouth: String(localized: "Direct (south-facing)")
        case .directEastWest: String(localized: "Direct (east or west-facing)")
        }
    }
}

/// Ambient humidity level at the plant's location.
enum HumidityPlacement: String, Sendable, Codable, CaseIterable {
    case dry
    case normal
    case wet

    var label: String {
        switch self {
        case .dry: String(localized: "Dry")
        case .normal: String(localized: "Normal")
        case .wet: String(localized: "Wet")
        }
    }
}

/// Raw output from a CoreML classifier, before mapping to catalog species.
struct RawClassificationResult: Sendable, Equatable {
    let topLabel: String
    let confidence: Double
    let alternatives: [AlternativeLabel]
}

struct AlternativeLabel: Sendable, Equatable {
    let label: String
    let confidence: Double
}

/// A detected plant region in a camera frame, in normalized (0–1) coordinates.
struct DetectedBoundingBox: Sendable, Equatable {
    let normalizedRect: CGRect
    let confidence: Double
}

/// Result of running plant detection on a camera frame.
struct DetectionResult: Sendable, Equatable {
    let boundingBoxes: [DetectedBoundingBox]
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
    /// Optional notes the user added when logging the event.
    var notes: String?
}

/// Kinds of care actions that can be logged.
enum CareEventType: String, Sendable, Codable, CaseIterable {
    case watered
    case fertilized
    case pruned
    case repotted
}

extension CareEventType {
    var localizedLabel: String {
        switch self {
        case .watered: String(localized: "Watering")
        case .fertilized: String(localized: "Fertilizing")
        case .pruned: String(localized: "Pruning")
        case .repotted: String(localized: "Repotting")
        }
    }

    var systemImage: String {
        switch self {
        case .watered: "drop.fill"
        case .fertilized: "leaf.arrow.circlepath"
        case .pruned: "scissors"
        case .repotted: "tray.full"
        }
    }

    var tint: Color {
        switch self {
        case .watered: .blue
        case .fertilized: .green
        case .pruned: .orange
        case .repotted: .brown
        }
    }

    var scheduleKeyPath: WritableKeyPath<CareSchedule, Date?> {
        switch self {
        case .watered: \.lastWatered
        case .fertilized: \.lastFertilized
        case .pruned: \.lastPruned
        case .repotted: \.lastRepotted
        }
    }
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

extension CareSchedule {
    mutating func recordEvent(_ type: CareEventType, on date: Date) {
        let keyPath = type.scheduleKeyPath
        if let last = self[keyPath: keyPath] {
            let daysLate = Calendar.current.dateComponents([.day], from: last, to: date).day ?? 0
            adherenceOffset = max(0, adherenceOffset + daysLate / 3 - 1)
        }
        self[keyPath: keyPath] = date
    }
}

/// A resolved city from a user's search query.
struct City: Equatable, Hashable, Sendable, Codable {
    var name: String
    var region: String
    var latitude: Double
    var longitude: Double
}

/// A scheduled care task produced by the scheduling engine.
struct CareTask: Identifiable, Sendable, Equatable {
    enum Status: String, Sendable, Equatable {
        case incomplete
        case completed
    }

    var id: String { "\(plantID.uuidString)-\(eventType.rawValue)" }
    /// The plant this task is for.
    var plantID: UUID
    /// Display name of the plant.
    var plantName: String
    /// The type of care to perform.
    var eventType: CareEventType
    /// When this task is due.
    var dueDate: Date
    /// Whether the due date has passed (convenience for display logic).
    var isOverdue: Bool { status == .incomplete && dueDate < Date.now }
    /// Current completion status of this task instance.
    var status: Status
}

