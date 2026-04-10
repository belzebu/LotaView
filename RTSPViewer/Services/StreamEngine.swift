import Foundation

actor StreamEngine {
    private var players: [Int: PlayerWrapper] = [:]
    private var reconnectTasks: [Int: Task<Void, Never>] = [:]

    func createPlayer(for slot: Int) -> PlayerWrapper {
        if let existing = players[slot] {
            return existing
        }
        let player = PlayerWrapper()
        players[slot] = player
        return player
    }

    func startStream(slot: Int, url: String, bufferDuration: Int = AppConstants.gridBufferDuration) {
        guard let player = players[slot] else { return }
        cancelReconnect(slot: slot)
        player.play(url: url, bufferDuration: bufferDuration)
    }

    func stopStream(slot: Int) {
        cancelReconnect(slot: slot)
        players[slot]?.stop()
    }

    func stopAll() {
        for (slot, _) in players {
            cancelReconnect(slot: slot)
        }
        for player in players.values {
            player.stop()
        }
    }

    func removePlayer(slot: Int) {
        cancelReconnect(slot: slot)
        players[slot]?.stop()
        players.removeValue(forKey: slot)
    }

    func removeAll() {
        for (slot, _) in players {
            cancelReconnect(slot: slot)
        }
        for player in players.values {
            player.stop()
        }
        players.removeAll()
    }

    func player(for slot: Int) -> PlayerWrapper? {
        players[slot]
    }

    func scheduleReconnect(slot: Int, url: String, attempt: Int = 0) {
        cancelReconnect(slot: slot)

        let delay = min(
            AppConstants.reconnectBaseDelay * pow(AppConstants.reconnectBackoffMultiplier, Double(attempt)),
            AppConstants.reconnectMaxDelay
        )

        reconnectTasks[slot] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.startStream(slot: slot, url: url)
        }
    }

    private func cancelReconnect(slot: Int) {
        reconnectTasks[slot]?.cancel()
        reconnectTasks.removeValue(forKey: slot)
    }
}
