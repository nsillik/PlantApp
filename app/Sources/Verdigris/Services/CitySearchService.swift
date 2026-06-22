@preconcurrency import MapKit

struct CitySuggestion: Equatable, Hashable, Sendable {
    var name: String
    var region: String
}

protocol CitySearchService: Sendable {
    func search(query: String) async throws -> [CitySuggestion]
    func resolve(_ suggestion: CitySuggestion) async throws -> City
}

final class MapKitCitySearchService: NSObject, @unchecked Sendable, CitySearchService {
    private let completer = MKLocalSearchCompleter()
    private var searchContinuation: CheckedContinuation<[MKLocalSearchCompletion], Error>?
    private var searchGeneration = 0

    override init() {
        super.init()
        completer.resultTypes = .address
        completer.delegate = self
    }

    @MainActor
    func search(query: String) async throws -> [CitySuggestion] {
        let generation = searchGeneration + 1
        searchGeneration = generation

        searchContinuation?.resume(throwing: CancellationError())
        searchContinuation = nil

        completer.cancel()
        completer.queryFragment = query

        let results = try await withCheckedThrowingContinuation { cont in
            searchContinuation = cont
        }

        guard searchGeneration == generation else { throw CancellationError() }

        return results.compactMap { completion -> CitySuggestion? in
            let title = completion.title.trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { return nil }
            let name: String
            let region: String
            if let commaIndex = title.firstIndex(of: ",") {
                name = title[..<commaIndex].trimmingCharacters(in: .whitespaces)
                let after = title[title.index(after: commaIndex)...].trimmingCharacters(in: .whitespaces)
                region = after + (completion.subtitle.isEmpty ? "" : ", \(completion.subtitle)")
            } else {
                name = title
                region = completion.subtitle.trimmingCharacters(in: .whitespaces)
            }
            return CitySuggestion(name: name, region: region)
        }
    }

    @MainActor
    func resolve(_ suggestion: CitySuggestion) async throws -> City {
        try await withCheckedThrowingContinuation { cont in
            let request = MKLocalSearch.Request()
            let query = suggestion.name + (!suggestion.region.isEmpty ? ", \(suggestion.region)" : "")
            request.naturalLanguageQuery = query
            request.resultTypes = .address
            let search = MKLocalSearch(request: request)
            search.start { response, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                guard let item = response?.mapItems.first else {
                    cont.resume(throwing: CitySearchError.notFound)
                    return
                }
                let placemark = item.placemark
                cont.resume(returning: City(
                    name: suggestion.name,
                    region: suggestion.region,
                    latitude: placemark.coordinate.latitude,
                    longitude: placemark.coordinate.longitude
                ))
            }
        }
    }
}

extension MapKitCitySearchService: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchContinuation?.resume(returning: completer.results)
        searchContinuation = nil
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        searchContinuation?.resume(throwing: error)
        searchContinuation = nil
    }
}

enum CitySearchError: Error, LocalizedError {
    case notFound
    case resolutionFailed

    var errorDescription: String? {
        switch self {
        case .notFound: String(localized: "Could not find that city. Try a different search.")
        case .resolutionFailed: String(localized: "Could not determine coordinates for that city.")
        }
    }
}
