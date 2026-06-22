import Foundation

protocol CatalogService: Sendable {
    func loadCatalog() async throws -> [PlantSpecies]
}

actor BundleCatalogService: CatalogService {
    private var cached: [PlantSpecies]?

    func loadCatalog() async throws -> [PlantSpecies] {
        if let cached { return cached }
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json") else {
            throw CatalogError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        let species = try JSONDecoder().decode([PlantSpecies].self, from: data)
        cached = species
        return species
    }
}

enum CatalogError: Error, LocalizedError {
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .fileNotFound: String(localized: "Catalog file not found in bundle")
        }
    }
}
