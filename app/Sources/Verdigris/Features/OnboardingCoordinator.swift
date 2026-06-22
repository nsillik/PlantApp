import Dependencies
import Foundation

enum OnboardingStep: Sendable {
    case location
    case addFirstPlant
    case complete
}

@MainActor
@Observable
final class OnboardingCoordinator {
    var currentStep: OnboardingStep = .location
    var userProfile: UserProfile?

    @ObservationIgnored
    @Dependency(\.userProfileRepository) private var profileRepository

    private let onboardingKey = "hasCompletedOnboarding"

    var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: onboardingKey)
    }

    func completeLocation(_ profile: UserProfile) {
        userProfile = profile
        currentStep = .addFirstPlant
    }

    func saveProfileAndComplete() async {
        if let profile = userProfile {
            try? await profileRepository.save(profile)
        }
        completeOnboarding()
    }

    func completeOnboarding() {
        currentStep = .complete
        UserDefaults.standard.set(true, forKey: onboardingKey)
    }

    func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: onboardingKey)
        userProfile = nil
        currentStep = .location
    }
}
