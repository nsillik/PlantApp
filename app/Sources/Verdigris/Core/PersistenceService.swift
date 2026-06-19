@preconcurrency import CoreData
import Foundation

/// Provides managed object contexts from the Core Data stack.
protocol PersistenceService: Sendable {
    /// The main-queue context, suitable for use with SwiftUI's `\.managedObjectContext` environment key.
    var viewContext: NSManagedObjectContext { get }

    /// Executes a block on a background context.
    ///
    /// The context is scoped to the closure — it cannot escape, ensuring it is never misused
    /// across actor boundaries.
    func withBackgroundContext<T: Sendable>(
        _ perform: @escaping @Sendable (NSManagedObjectContext) throws -> T
    ) async throws -> T
}
