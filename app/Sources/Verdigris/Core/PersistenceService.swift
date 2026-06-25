@preconcurrency import CoreData
import Foundation

/// Provides managed object contexts from the Core Data stack.
protocol PersistenceService: Sendable {
    func withBackgroundContext<T>(
        _ perform: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T

    func fetchAll<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        predicate: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [T]

    func fetchFirst<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        predicate: NSPredicate?
    ) async throws -> T?

    func upsert<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        predicate: NSPredicate?,
        configure: @escaping (T) -> Void
    ) async throws

    func deleteAll<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        predicate: NSPredicate?
    ) async throws
}

extension PersistenceService {
    func fetchAll<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil
    ) async throws -> [T] {
        try await fetchAll(request, predicate: predicate, sortDescriptors: sortDescriptors)
    }

    func fetchFirst<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        predicate: NSPredicate? = nil
    ) async throws -> T? {
        try await fetchFirst(request, predicate: predicate)
    }

    func upsert<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        predicate: NSPredicate? = nil,
        configure: @escaping (T) -> Void
    ) async throws {
        try await upsert(request, predicate: predicate, configure: configure)
    }

    func deleteAll<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        predicate: NSPredicate? = nil
    ) async throws {
        try await deleteAll(request, predicate: predicate)
    }
}
