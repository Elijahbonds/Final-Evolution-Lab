import Foundation
import CryptoKit

/// Pro-Coach **Sovereign Invite Codes**: HMAC-signed payloads that bind a coach `CreatorID` to an athlete on **first System Scan** completion.
/// Server-side validation is recommended for production scale; local HMAC matches the shipped bundle for offline QA and elite cohort rollout.
final class UFELCreatorInviteService: @unchecked Sendable {
    static let shared = UFELCreatorInviteService()

    private let pendingRawKey = "felPendingSovereignInviteCodeRaw"
    private let symmetricKey: SymmetricKey

    private init() {
        let bundle = Bundle.main.bundleIdentifier ?? "com.finalevolution.fel"
        let seedFromPlist = Bundle.main.object(forInfoDictionaryKey: "FELInviteSigningSeed") as? String
        let material = (seedFromPlist?.isEmpty == false ? seedFromPlist! : bundle) + "\nFEL_SOVEREIGN_INVITE_V1"
        let digest = SHA256.hash(data: Data(material.utf8))
        symmetricKey = SymmetricKey(data: Data(digest))
    }

    // MARK: - Generation (coach / dashboard)

    /// Returns a shareable code encoding `creatorId` (your Pro-Coach `CreatorID`). Unique per call via nonce.
    func generateSovereignInviteCode(creatorId: String) -> String {
        let trimmed = creatorId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let payload = InvitePayload(v: 1, c: trimmed, n: UUID().uuidString)
        guard let body = try? JSONEncoder().encode(payload) else { return "" }
        let tag = HMAC<SHA256>.authenticationCode(for: body, using: symmetricKey)
        let tagPrefix = Data(tag.prefix(8))
        let bodyB64 = Self.base64urlEncode(body)
        let tagB64 = Self.base64urlEncode(tagPrefix)
        return "FELSV1.\(bodyB64).\(tagB64)"
    }

    // MARK: - Pending registration (athlete enters before first scan)

    /// Validates format and stores for redemption on first System Scan. Returns false if malformed.
    func registerPendingInviteCode(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, parseCreatorId(from: trimmed) != nil else {
            UserDefaults.standard.removeObject(forKey: pendingRawKey)
            return false
        }
        UserDefaults.standard.set(trimmed, forKey: pendingRawKey)
        return true
    }

    func clearPendingInviteCode() {
        UserDefaults.standard.removeObject(forKey: pendingRawKey)
    }

    var pendingInviteCodeDisplay: String? {
        UserDefaults.standard.string(forKey: pendingRawKey)
    }

    // MARK: - First System Scan

    /// Call from the **first-launch** `SystemScanView` completion handler only. Mutates `profile` when a pending code redeems.
    func applyPendingInviteOnFirstScanCompletion(profile: inout UserProfile) -> Bool {
        guard profile.linkedCoachCreatorId == nil else { return false }
        guard let raw = UserDefaults.standard.string(forKey: pendingRawKey), !raw.isEmpty else { return false }
        guard let creatorId = parseCreatorId(from: raw) else { return false }
        profile.linkedCoachCreatorId = creatorId
        profile.coachInviteLinkedAt = Date()
        UserDefaults.standard.removeObject(forKey: pendingRawKey)
        return true
    }

    /// Validates a code without storing (e.g. UI feedback).
    func parseCreatorId(from raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix("FELSV1.") else { return nil }
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == "FELSV1" else { return nil }
        guard let body = Self.base64urlDecode(String(parts[1])),
              let tag = Self.base64urlDecode(String(parts[2])) else { return nil }
        let expected = HMAC<SHA256>.authenticationCode(for: body, using: symmetricKey)
        guard tag.count == 8, expected.prefix(8).elementsEqual(tag) else { return nil }
        guard let payload = try? JSONDecoder().decode(InvitePayload.self, from: body), payload.v == 1 else { return nil }
        let id = payload.c.trimmingCharacters(in: .whitespacesAndNewlines)
        return id.isEmpty ? nil : id
    }

    private struct InvitePayload: Codable {
        let v: Int
        let c: String
        let n: String
    }

    private static func base64urlEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64urlDecode(_ s: String) -> Data? {
        var t = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let pad = 4 - t.count % 4
        if pad < 4 { t += String(repeating: "=", count: pad) }
        return Data(base64Encoded: t)
    }
}
