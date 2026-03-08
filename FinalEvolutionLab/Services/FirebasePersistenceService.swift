import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct CloudAppSnapshot: Codable {
    let profile: UserProfile
    let sessions: [WorkoutSession]
    let gameResults: [GameSessionResult]
    let coachEconomy: CoachEconomy
    let critiqueRequests: [CritiqueRequest]
    let trainingProgress: TrainingProgress
    let updatedAt: Date
}

enum FirebasePersistenceService {
    static func pushSnapshot(_ snapshot: CloudAppSnapshot) async {
#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        FirebaseBootstrap.configureIfNeeded()
        guard let userId = await ensureAnonymousUserId() else { return }
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }

        let document: [String: Any] = [
            "payloadVersion": 1,
            "updatedAt": Timestamp(date: snapshot.updatedAt),
            "blob": encoded.base64EncodedString()
        ]

        do {
            let db = Firestore.firestore()
            try await db.collection("users")
                .document(userId)
                .collection("state")
                .document("snapshot")
                .setData(document, merge: true)
        } catch {
            print("[FirebasePersistenceService] Push failed: \(error.localizedDescription)")
        }
#endif
    }

    static func pullSnapshot() async -> CloudAppSnapshot? {
#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        FirebaseBootstrap.configureIfNeeded()
        guard let userId = await ensureAnonymousUserId() else { return nil }

        do {
            let db = Firestore.firestore()
            let document = try await db.collection("users")
                .document(userId)
                .collection("state")
                .document("snapshot")
                .getDocument()

            guard let data = document.data(),
                  let blob = data["blob"] as? String,
                  let encoded = Data(base64Encoded: blob),
                  let snapshot = try? JSONDecoder().decode(CloudAppSnapshot.self, from: encoded) else {
                return nil
            }

            return snapshot
        } catch {
            print("[FirebasePersistenceService] Pull failed: \(error.localizedDescription)")
            return nil
        }
#else
        return nil
#endif
    }

#if canImport(FirebaseAuth)
    private static func ensureAnonymousUserId() async -> String? {
        if let user = Auth.auth().currentUser {
            return user.uid
        }

        do {
            let result = try await Auth.auth().signInAnonymously()
            return result.user.uid
        } catch {
            print("[FirebasePersistenceService] Anonymous sign-in failed: \(error.localizedDescription)")
            return nil
        }
    }
#endif
}
