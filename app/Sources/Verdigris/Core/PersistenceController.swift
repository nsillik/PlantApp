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
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                print("Warning: Failed to load in-memory persistent store: \(error)")
            }
        }
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
}
