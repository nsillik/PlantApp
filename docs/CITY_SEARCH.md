# City Search Design

## Problem

We need the user to pick a city during onboarding and optionally change it later in settings. The city selection must produce a latitude/longitude pair and a climate classification to drive personalized care recommendations.

## Current approach

Both `LocationOnboardingView` and `SettingsView` use a shared `CitySearchService` injected via `@Dependency`. The service uses a two-step flow:

1. **Search** — `MKLocalSearchCompleter` returns fast text suggestions as the user types (debounced 400ms).
2. **Resolve** — When the user taps a suggestion, `MKLocalSearch` resolves it to coordinates.

This avoids the limitations of using `MKLocalSearch` alone (which returns very few results for short prefix queries) while keeping the coordinate resolution step separate from the suggestion step.

### Protocol

```swift
protocol CitySearchService: Sendable {
    func search(query: String) async throws -> [CitySuggestion]
    func resolve(_ suggestion: CitySuggestion) async throws -> City
}
```

`CitySuggestion` is a lightweight struct (text only, no coordinates):

```swift
struct CitySuggestion: Equatable, Hashable, Sendable {
    var name: String
    var region: String
}
```

`City` is the fully resolved domain struct with coordinates:

```swift
struct City: Equatable, Hashable, Sendable, Codable {
    var name: String
    var region: String
    var latitude: Double
    var longitude: Double
}
```

The `ClimateClassification` is derived from latitude at the call site (onboarding/settings ViewModel), not inside the service.

### Implementation

`MapKitCitySearchService` is a `@unchecked Sendable` class (it uses `MKLocalSearchCompleter` which is not Sendable). The `search` method uses `MKLocalSearchCompleter` bridged to async/await via `withCheckedThrowingContinuation` + a delegate. The `resolve` method uses `MKLocalSearch` with `.address` result type.

### ViewModel flow

1. User types → `onChange(of: searchText)` triggers `searchCities()` with 400ms debounce
2. `searchCities()` calls `searchService.search(query:)` → populates `suggestions: [CitySuggestion]`
3. User taps a suggestion → `selectSuggestion(_:)` calls `searchService.resolve(_:)` → populates `selectedCity: City?`
4. User taps confirm → `buildProfile()` constructs `UserProfile` from the selected city

Both `LocationOnboardingViewModel` and `SettingsViewModel` follow the same pattern.

### Key design decisions

1. **Two-step flow** — `MKLocalSearchCompleter` (suggestions) + `MKLocalSearch` (coordinates). Using `MKLocalSearch` alone for autocomplete returns very few results for short queries because it's designed for specific place lookups, not prefix matching.
2. **Debounced search** — 400ms debounce on text changes prevents excessive API calls while keeping the UI responsive.
3. **Generation counter** — prevents stale search results from overwriting newer ones when the user types quickly.
4. **`ClimateClassification` at call site** — the service just resolves locations; climate is derived from latitude by the ViewModel.
5. **Single implementation** — both onboarding and settings call the same `@Dependency(\.citySearchService)`.
6. **Testable** — mock the service in tests; no real MapKit calls during unit tests.
7. **Swappable** — replace MapKit with a different provider (e.g., a bundled city list) by writing a new conformance.
