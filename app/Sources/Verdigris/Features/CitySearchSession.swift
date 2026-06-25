import Dependencies
import Foundation

@MainActor
@Observable
final class CitySearchSession {
    var searchText = ""
    var isSearching = false
    var isResolving = false
    var errorMessage: String?
    var suggestions: [CitySuggestion] = []
    var selectedCity: City?

    @ObservationIgnored
    @Dependency(\.citySearchService) private var searchService
    @ObservationIgnored
    @Dependency(\.climateService) private var climateService

    private var searchTask: Task<Void, Never>?

    func searchCities() {
        searchTask?.cancel()
        let text = searchText.trimmingCharacters(in: .whitespaces)
        if text.isEmpty {
            suggestions = []
            selectedCity = nil
            isSearching = false
            errorMessage = nil
            return
        }
        if let city = selectedCity, text == city.name {
            return
        }
        selectedCity = nil
        suggestions = []
        isSearching = true
        errorMessage = nil
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard let self else { return }
            guard !Task.isCancelled else { return }
            do {
                let results = try await searchService.search(query: text)
                guard !Task.isCancelled else { return }
                suggestions = results
                isSearching = false
            } catch {
                guard !Task.isCancelled else { return }
                suggestions = []
                errorMessage = error.localizedDescription
                isSearching = false
            }
        }
    }

    func selectSuggestion(_ suggestion: CitySuggestion) {
        let savedSuggestions = suggestions

        searchTask?.cancel()
        isResolving = true
        errorMessage = nil
        suggestions = []
        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let city = try await searchService.resolve(suggestion)
                guard !Task.isCancelled else { return }
                selectedCity = city
                searchText = city.name
                isResolving = false
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
                isResolving = false
                suggestions = savedSuggestions
            }
        }
    }

    func climateLabel(for city: City) -> String {
        climateService.climateClassification(for: city).localizedLabel
    }

    func reset() {
        searchText = ""
        isSearching = false
        isResolving = false
        errorMessage = nil
        suggestions = []
        selectedCity = nil
        searchTask?.cancel()
        searchTask = nil
    }
}
