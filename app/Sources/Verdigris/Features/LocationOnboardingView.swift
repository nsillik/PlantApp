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
    let citySession = CitySearchSession()

    @ObservationIgnored
    @Dependency(\.climateService) private var climateService

    /// Constructs the persisted `UserProfile` from the currently selected city.
    /// Returns `nil` if no city is selected.
    func buildProfile() -> UserProfile? {
        guard let city = citySession.selectedCity else { return nil }
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
                TextField(String(localized: "Search city…"), text: $viewModel.citySession.searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
                List(viewModel.citySession.suggestions, id: \.self) { suggestion in
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
                .listStyle(.plain)
            }

            if let city = viewModel.citySession.selectedCity {
                VStack(alignment: .leading, spacing: 4) {
                    Text(city.name)
                        .font(.headline)
                    Text(String(localized: "\(viewModel.citySession.climateLabel(for: city)) climate"))
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
