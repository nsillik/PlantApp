import CoreData
import Foundation

@objc(PlantEntity)
final class PlantEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var dateAdded: Date?
    @NSManaged var speciesID: UUID?
    @NSManaged var placementLight: String?
    @NSManaged var placementHumidity: String?

    @nonobjc static func fetchRequest() -> NSFetchRequest<PlantEntity> {
        NSFetchRequest<PlantEntity>(entityName: "PlantEntity")
    }
}

@objc(PlantSpeciesEntity)
final class PlantSpeciesEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var commonName: String?
    @NSManaged var scientificName: String?
    @NSManaged var lightNeeds: String?
    @NSManaged var wateringInterval: Int32
    @NSManaged var soilType: String?
    @NSManaged var humidityRange: String?
    @NSManaged var toxicity: String?
    @NSManaged var growthHabit: String?
    @NSManaged var commonIssues: NSObject?
    @NSManaged var imageURLs: NSObject?

    @nonobjc static func fetchRequest() -> NSFetchRequest<PlantSpeciesEntity> {
        NSFetchRequest<PlantSpeciesEntity>(entityName: "PlantSpeciesEntity")
    }
}

@objc(UserProfileEntity)
final class UserProfileEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var city: String?
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var climateClassification: String?

    @nonobjc static func fetchRequest() -> NSFetchRequest<UserProfileEntity> {
        NSFetchRequest<UserProfileEntity>(entityName: "UserProfileEntity")
    }
}

@objc(CareEventEntity)
final class CareEventEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var plantID: UUID?
    @NSManaged var eventType: String?
    @NSManaged var timestamp: Date?
    @NSManaged var photoData: Data?
    @NSManaged var notes: String?

    @nonobjc static func fetchRequest() -> NSFetchRequest<CareEventEntity> {
        NSFetchRequest<CareEventEntity>(entityName: "CareEventEntity")
    }
}

@objc(CareScheduleEntity)
final class CareScheduleEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var plantID: UUID?
    @NSManaged var lastWatered: Date?
    @NSManaged var lastFertilized: Date?
    @NSManaged var lastPruned: Date?
    @NSManaged var lastRepotted: Date?
    @NSManaged var adherenceOffset: Int32

    @nonobjc static func fetchRequest() -> NSFetchRequest<CareScheduleEntity> {
        NSFetchRequest<CareScheduleEntity>(entityName: "CareScheduleEntity")
    }
}
