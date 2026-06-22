import Dependencies
import SwiftUI

/// Owns the city-search and profile-editing state for the Settings screen.
///
/// Shares the same `CitySearchService`-driven search/resolve flow as
/// `LocationOnboardingViewModel`, but also handles saving the updated profile
/// to the repository and toggling edit mode.
@MainActor
@Observable
final class SettingsViewModel {
    /// The currently persisted profile, loaded on appear.
    var currentProfile: UserProfile?
    /// Whether the user is editing the location field.
    var isEditingLocation = false
    /// Current text in the search field (visible only when editing).
    var searchText = ""
    /// True while the autocomplete search is in flight.
    var isSearching = false
    /// True while resolving a selected suggestion to coordinates.
    var isResolving = false
    /// Non-nil when the last search or resolution failed.
    var errorMessage: String?
    /// Autocomplete city suggestions from `CitySearchService.search`.
    var suggestions: [CitySuggestion] = []
    /// The city the user has tapped and resolved. Nil until a selection is made.
    var selectedCity: City?

    @ObservationIgnored
    @Dependency(\.userProfileRepository) private var profileRepository
    @ObservationIgnored
    @Dependency(\.citySearchService) private var searchService

    private var searchTask: Task<Void, Never>?

    /// Fetches the existing profile from the repository.
    func loadProfile() async {
        currentProfile = try? await profileRepository.fetch()
    }

    /// Debounced search: waits 400ms after the last keystroke, then calls
    /// `CitySearchService.search`. Cancels any in-flight search first.
    /// Guards against re-searching when the text matches `selectedCity.name`.
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
            guard let self, !Task.isCancelled else { return }
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

    /// Kicks off coordinate resolution for the tapped suggestion.
    ///
    /// Calls `CitySearchService.resolve` and on success sets `selectedCity` and
    /// fills the text field. On failure the error message is displayed.
    func selectSuggestion(_ suggestion: CitySuggestion) {
        searchTask?.cancel()
        isResolving = true
        errorMessage = nil
        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let city = try await searchService.resolve(suggestion)
                guard !Task.isCancelled else { return }
                selectedCity = city
                suggestions = []
                searchText = city.name
                isResolving = false
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
                isResolving = false
            }
        }
    }

    /// Persists the resolved city as the new profile and exits edit mode.
    func confirmCity() async {
        guard let city = selectedCity else { return }
        let absLat = abs(city.latitude)
        let climate: ClimateClassification
        switch absLat {
        case 0..<15: climate = .tropical
        case 15..<30: climate = .arid
        default: climate = .temperate
        }

        let profile = UserProfile(
            id: currentProfile?.id ?? UUID(),
            city: city.name,
            latitude: city.latitude,
            longitude: city.longitude,
            climateClassification: climate
        )

        try? await profileRepository.save(profile)
        currentProfile = profile
        isEditingLocation = false
        searchText = ""
        selectedCity = nil
        suggestions = []
    }
}

struct SettingsView: View {
    let onResetOnboarding: () -> Void
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Location")) {
                    if let profile = viewModel.currentProfile, !viewModel.isEditingLocation {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(profile.city)
                                    .font(.headline)
                                Text(String(localized: "\(profile.climateClassification.rawValue.capitalized) climate"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(String(localized: "Edit")) {
                                viewModel.isEditingLocation = true
                            }
                        }
                    }

                    if viewModel.isEditingLocation {
                        VStack(spacing: 12) {
                            TextField(String(localized: "Search city…"), text: $viewModel.searchText)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .onChange(of: viewModel.searchText) { _, _ in
                                    viewModel.searchCities()
                                }

                            if viewModel.isResolving {
                                ProgressView(String(localized: "Resolving location…"))
                            } else if viewModel.isSearching {
                                ProgressView()
                            }

                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }

                            if !viewModel.suggestions.isEmpty {
                                ForEach(viewModel.suggestions, id: \.self) { suggestion in
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
                            }

                            if let city = viewModel.selectedCity {
                                VStack(alignment: .leading) {
                                    Text(city.name)
                                        .font(.headline)
                                }

                                Button(String(localized: "Confirm")) {
                                    Task { await viewModel.confirmCity() }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }

                Section(String(localized: "Onboarding")) {
                    Button(String(localized: "Reset Onboarding")) {
                        onResetOnboarding()
                    }
                    .foregroundStyle(.red)
                }

                Section(String(localized: "AI Provider")) {
                    Text(String(localized: "AI diagnosis provider configuration will be available in a future update."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(String(localized: "Settings"))
        }
        .task {
            await viewModel.loadProfile()
        }
    }
}
