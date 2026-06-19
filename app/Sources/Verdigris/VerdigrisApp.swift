import Dependencies
import SwiftUI

@main
struct VerdigrisApp: App {
    @Dependency(\.persistenceService) private var persistenceService

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.managedObjectContext, persistenceService.viewContext)
        }
    }
}
