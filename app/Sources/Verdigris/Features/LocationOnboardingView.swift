import Dependencies
import SwiftUI

/// Owns the city-search state for the onboarding location step.
///
/// Performs a debounced search as the user types, displays suggestions from
/// `MKLocalSearchCompleter`, resolves the selected suggestion to coordinates,
/// and builds a `UserProfile` on confirmation.
@MainActor
@Observable
final class LocationOnboardingViewModel {
    /// Current text in the search field.
    var searchText = ""
    /// True while the autocomplete search is in flight.
    var isLoading = false
    /// True while resolving a selected suggestion to coordinates.
    var isResolving = false
    /// Non-nil when the last search or resolution failed.
    var errorMessage: String?
    /// Autocomplete city suggestions from `CitySearchService.search`.
    var suggestions: [CitySuggestion] = []
    /// The city the user has tapped and resolved. Nil until a selection is confirmed.
    var selectedCity: City?

    @ObservationIgnored
    @Dependency(\.citySearchService) private var searchService
    @ObservationIgnored
    @Dependency(\.climateService) private var climateService

    private var searchTask: Task<Void, Never>?

    /// Debounced search: waits 400ms after the last keystroke, then calls
    /// `CitySearchService.search`. Cancels any in-flight search first.
    /// Guards against re-searching when the text matches `selectedCity.name`.
    func searchCities() {
        searchTask?.cancel()
        let text = searchText.trimmingCharacters(in: .whitespaces)
        if text.isEmpty {
            suggestions = []
            selectedCity = nil
            isLoading = false
            errorMessage = nil
            return
        }
        if let city = selectedCity, text == city.name {
            return
        }
        selectedCity = nil
        suggestions = []
        isLoading = true
        errorMessage = nil
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard let self, !Task.isCancelled else { return }
            do {
                let results = try await searchService.search(query: text)
                guard !Task.isCancelled else { return }
                suggestions = results
                isLoading = false
            } catch {
                guard !Task.isCancelled else { return }
                suggestions = []
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    /// Kicks off coordinate resolution for the tapped suggestion.
    ///
    /// Calls `CitySearchService.resolve` and on success sets `selectedCity` and
    /// fills the text field. On failure it restores the previous suggestions so
    /// the user can try a different entry.
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

    /// Returns the climate classification label for display purposes.
    func climateLabel(for city: City) -> String {
        climateService.climateClassification(for: city).rawValue
    }

    /// Constructs the persisted `UserProfile` from the currently selected city.
    /// Returns `nil` if no city is selected.
    func buildProfile() -> UserProfile? {
        guard let city = selectedCity else { return nil }
        return UserProfile(
            id: UUID(),
            city: city.name,
            latitude: city.latitude,
            longitude: city.longitude,
            climateClassification: climateService.climateClassification(for: city)
        )
    }
}

struct LocationOnboardingView: View {
    @State private var viewModel = LocationOnboardingViewModel()
    let onComplete: (UserProfile) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text(String(localized: "Where are you?"))
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(String(localized: "Enter your city so we can personalize care recommendations."))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(String(localized: "Search city…"), text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.searchCities()
            }

            if viewModel.isResolving {
                ProgressView(String(localized: "Resolving location…"))
            } else if viewModel.isLoading {
                ProgressView()
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !viewModel.suggestions.isEmpty {
                List(viewModel.suggestions, id: \.self) { suggestion in
                    Button {
                        viewModel.selectSuggestion(suggestion)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.name)
                                .font(.headline)
                            if !suggestion.region.isEmpty {
                                Text(suggestion.region)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .listStyle(.plain)
            }

            if let city = viewModel.selectedCity {
                VStack(alignment: .leading, spacing: 4) {
                    Text(city.name)
                        .font(.headline)
                    Text(String(localized: "\(viewModel.climateLabel(for: city).capitalized) climate"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button(String(localized: "Confirm Location")) {
                    if let profile = viewModel.buildProfile() {
                        onComplete(profile)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Spacer()
        }
        .padding()
    }
}
