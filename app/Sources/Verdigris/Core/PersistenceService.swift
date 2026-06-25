@preconcurrency import CoreData
import Foundation

/// Provides managed object contexts from the Core Data stack.
protocol PersistenceService: Sendable {
    /// Executes a block on a background context.
    ///
    /// The context is scoped to the closure — it cannot escape, ensuring it is never misused
    /// across actor boundaries.
    func withBackgroundContext<T: Sendable>(
        _ perform: @escaping @Sendable (NSManagedObjectContext) throws -> T
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
        configure: @Sendable @escaping (T) -> Void
    ) async throws

    func deleteAll<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        predicate: NSPredicate?
    ) async throws
}
