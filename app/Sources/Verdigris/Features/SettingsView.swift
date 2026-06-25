import Dependencies
import SwiftUI

/// Owns the city-search and profile-editing state for the Settings screen.
///
/// Composes `CitySearchSession` for the search/resolve flow and handles
/// saving the updated profile to the repository and toggling edit mode.
@MainActor
@Observable
final class SettingsViewModel {
    let citySession = CitySearchSession()
    /// The currently persisted profile, loaded on appear.
    var currentProfile: UserProfile?
    /// Whether the user is editing the location field.
    var isEditingLocation = false

    @ObservationIgnored
    @Dependency(\.userProfileRepository) private var profileRepository
    @ObservationIgnored
    @Dependency(\.climateService) private var climateService

    /// Fetches the existing profile from the repository.
    func loadProfile() async {
        do {
            currentProfile = try await profileRepository.fetch()
            citySession.searchText = currentProfile?.city ?? ""
        } catch {
            reportIssue("""
              Failed to load profile: \(error.localizedDescription)
              """)
        }
    }

    /// Persists the resolved city as the new profile and exits edit mode.
    func confirmCity() async {
        guard let city = citySession.selectedCity else { return }

        let profile = UserProfile(
            id: currentProfile?.id ?? UUID(),
            city: city.name,
            latitude: city.latitude,
            longitude: city.longitude,
            climateClassification: climateService.climateClassification(for: city)
        )

        try? await profileRepository.save(profile)
        currentProfile = profile
        isEditingLocation = false
        citySession.reset()
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
                                Text(String(localized: "\(profile.climateClassification.localizedLabel) climate"))
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
                            TextField(String(localized: "Search city…"), text: $viewModel.citySession.searchText)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .onChange(of: viewModel.citySession.searchText) { _, _ in
                                    viewModel.citySession.searchCities()
                                }

                            if viewModel.citySession.isResolving {
                                ProgressView(String(localized: "Resolving location…"))
                            } else if viewModel.citySession.isSearching {
                                ProgressView()
                            }

                            if let error = viewModel.citySession.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }

                            if !viewModel.citySession.suggestions.isEmpty {
                                ForEach(viewModel.citySession.suggestions, id: \.self) { suggestion in
                                    Button {
                                        viewModel.citySession.selectSuggestion(suggestion)
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

                            if let city = viewModel.citySession.selectedCity {
                                VStack(alignment: .leading) {
                                    Text(city.name)
                                        .font(.headline)
                                    Text(viewModel.citySession.climateLabel(for: city))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
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
