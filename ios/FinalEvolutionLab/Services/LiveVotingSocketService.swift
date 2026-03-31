import Foundation

@MainActor
final class LiveVotingSocketService {
    private var listenersByEvent: [String: [UUID: AsyncStream<LiveVote>.Continuation]] = [:]

    func connect(eventId: String) -> AsyncStream<LiveVote> {
        let token = UUID()
        return AsyncStream { continuation in
            listenersByEvent[eventId, default: [:]][token] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.disconnect(eventId: eventId, token: token)
                }
            }
        }
    }

    func publish(vote: LiveVote) {
        let listeners = listenersByEvent[vote.eventId] ?? [:]
        for continuation in listeners.values {
            continuation.yield(vote)
        }
    }

    func close(eventId: String) {
        let listeners = listenersByEvent[eventId] ?? [:]
        for continuation in listeners.values {
            continuation.finish()
        }
        listenersByEvent[eventId] = nil
    }

    private func disconnect(eventId: String, token: UUID) {
        listenersByEvent[eventId]?[token] = nil
        if listenersByEvent[eventId]?.isEmpty == true {
            listenersByEvent[eventId] = nil
        }
    }
}
