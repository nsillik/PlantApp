@preconcurrency import CoreData
import Foundation

final class PersistenceController: PersistenceService {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    private init() {
        let modelURL = Bundle.main.url(forResource: "Verdigris", withExtension: "momd")!
        let model = NSManagedObjectModel(contentsOf: modelURL)!
        container = NSPersistentCloudKitContainer(name: "Verdigris", managedObjectModel: model)

        guard let storeDescription = container.persistentStoreDescriptions.first else {
            fatalError("No persistent store description found")
        }

        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.verdigris"
        )

        container.loadPersistentStores { _, error in
            if let error {
                print("Warning: Failed to load persistent store: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    static func inMemory() -> PersistenceController {
        let controller = PersistenceController(inMemory: true)
        return controller
    }

    private init(inMemory: Bool) {
        let modelURL = Bundle.main.url(forResource: "Verdigris", withExtension: "momd")!
        let model = NSManagedObjectModel(contentsOf: modelURL)!
        container = NSPersistentCloudKitContainer(name: "Verdigris", managedObjectModel: model)

        if inMemory {
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("No persistent store description found")
            }
            description.url = URL(fileURLWithPath: "/dev/null")
            description.type = NSInMemoryStoreType
        }

        container.loadPersistentStores { _, error in
            if let error {
                print("Warning: Failed to load in-memory persistent store: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func saveContext() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }

    func withBackgroundContext<T: Sendable>(
        _ perform: @escaping @Sendable (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                do {
                    let result = try perform(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchAll<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil
    ) async throws -> [T] {
        try await withBackgroundContext { context in
            request.predicate = predicate
            request.sortDescriptors = sortDescriptors
            return try context.fetch(request)
        }
    }

    func fetchFirst<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        predicate: NSPredicate? = nil
    ) async throws -> T? {
        try await withBackgroundContext { context in
            request.predicate = predicate
            request.fetchLimit = 1
            return try context.fetch(request).first
        }
    }

    func upsert<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        predicate: NSPredicate? = nil,
        configure: @Sendable @escaping (T) -> Void
    ) async throws {
        try await withBackgroundContext { context in
            request.predicate = predicate
            let existing = try context.fetch(request)
            let entity = existing.first ?? T(context: context)
            configure(entity)
            try context.save()
        }
    }

    func deleteAll<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        predicate: NSPredicate? = nil
    ) async throws {
        try await withBackgroundContext { context in
            request.predicate = predicate
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            try context.save()
        }
    }
}
