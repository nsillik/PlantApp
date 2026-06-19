import Dependencies
import Foundation

enum StubWeatherServiceKey: DependencyKey {
    static let liveValue: Void = ()
}

enum StubAIDiagnosisProviderKey: DependencyKey {
    static let liveValue: Void = ()
}

extension DependencyValues {
    var weatherService: Void {
        get { self[StubWeatherServiceKey.self] }
        set { self[StubWeatherServiceKey.self] = newValue }
    }

    var aiDiagnosisProvider: Void {
        get { self[StubAIDiagnosisProviderKey.self] }
        set { self[StubAIDiagnosisProviderKey.self] = newValue }
    }
}
