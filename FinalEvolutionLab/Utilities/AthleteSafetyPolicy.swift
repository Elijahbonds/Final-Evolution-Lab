import Foundation

/// Age / guardian gates for public social, HealthKit, and paid coaching surfaces (MINORS-01 / PRIVACY-09).
enum AthleteSafetyPolicy {
    /// Athletes under 18 need guardian acknowledgment before certain surfaces are enabled.
    static func assertSensitiveMinorGate(profile: UserProfile) throws {
        guard let age = profile.age else { return }
        guard age < 18 else { return }
        guard profile.guardianConsentForMinorFeatures else {
            throw TrainingLabSocialBridgeError.minorRequiresGuardianConsent
        }
    }

    /// Known minor when ``age`` is set and under 18; unknown age returns false (server also enforces policy).
    static func isMinorProfile(age: Int?) -> Bool {
        guard let age else { return false }
        return age < 18
    }

    /// Mirrors backend `/social/athletes`: explicit discovery opt-in **and** minors only when guardian consent is on.
    static func publicAthleteDiscoveryAllowed(profile: UserProfile, discoveryOptIn: Bool) -> Bool {
        guard discoveryOptIn else { return false }
        if isMinorProfile(age: profile.age), !profile.guardianConsentForMinorFeatures {
            return false
        }
        return true
    }

    /// PRQ must not appear in public athlete search for minors (even if metrics opt-in exists server-side).
    static func publicAthleteSearchOmitsPRQForMinor(profile: UserProfile) -> Bool {
        isMinorProfile(age: profile.age)
    }
}
