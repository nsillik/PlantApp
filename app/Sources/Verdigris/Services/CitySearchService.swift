/// `@preconcurrency import` needed because MKLocalSearchCompleter and its delegate
/// are not fully Sendable-annotated in the SDK version pinned.
@preconcurrency import MapKit

struct CitySuggestion: Equatable, Hashable, Sendable {
    var name: String
    var region: String
}

protocol CitySearchService: Sendable {
    func search(query: String) async throws -> [CitySuggestion]
    func resolve(_ suggestion: CitySuggestion) async throws -> City
}

@MainActor
final class MapKitCitySearchService: NSObject, @unchecked Sendable, CitySearchService {
    private let completer = MKLocalSearchCompleter()
    private var activeContinuation: CheckedContinuation<[MKLocalSearchCompletion], any Error>?

    override init() {
        super.init()
        completer.resultTypes = .address
        completer.delegate = self
    }

    func search(query: String) async throws -> [CitySuggestion] {
        completer.cancel()
        activeContinuation?.resume(throwing: CancellationError())
        activeContinuation = nil

        let completer = self.completer
        let results = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { cont in
                activeContinuation = cont
                completer.queryFragment = query
            }
        } onCancel: {
            completer.cancel()
            MainActor.assumeIsolated {
                activeContinuation?.resume(throwing: CancellationError())
                activeContinuation = nil
            }
        }

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
                    cont.resume(throwing: CitySearchError.resolutionFailed)
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

extension MapKitCitySearchService: @preconcurrency MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        activeContinuation?.resume(returning: completer.results)
        activeContinuation = nil
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        activeContinuation?.resume(throwing: error)
        activeContinuation = nil
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
