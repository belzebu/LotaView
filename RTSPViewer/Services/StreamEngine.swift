import Foundation

actor StreamEngine {
    private var players: [Int: PlayerWrapper] = [:]
    private var reconnectTasks: [Int: Task<Void, Never>] = [:]

    // Serialize RTSP handshakes so the NVR sees at most one in-flight DESCRIBE
    // at a time. Many consumer NVRs (Hikvision, Dahua) reject concurrent
    // handshakes with TCP RST even when they have free session capacity.
    private var handshakeInFlight: Bool = false
    private var pendingConnects: [(slot: Int, url: String, bufferDuration: Int)] = []
    private var handshakeTimeoutTask: Task<Void, Never>? = nil

    func createPlayer(for slot: Int) -> PlayerWrapper {
        if let existing = players[slot] {
            return existing
        }
        let player = PlayerWrapper()
        players[slot] = player
        return player
    }

    func startStream(slot: Int, url: String, bufferDuration: Int = AppConstants.gridBufferDuration) {
        guard players[slot] != nil else { return }
        cancelReconnect(slot: slot)

        if handshakeInFlight {
            pendingConnects.removeAll { $0.slot == slot }
            pendingConnects.append((slot, url, bufferDuration))
            return
        }

        beginHandshake(slot: slot, url: url, bufferDuration: bufferDuration)
    }

    private func beginHandshake(slot: Int, url: String, bufferDuration: Int) {
        handshakeInFlight = true
        scheduleHandshakeTimeout(slot: slot)
        players[slot]?.play(url: url, bufferDuration: bufferDuration)
    }

    /// Force-release the handshake gate if a slot's RTSP handshake never
    /// completes (e.g. TCP connected but server went silent).
    private func scheduleHandshakeTimeout(slot: Int) {
        handshakeTimeoutTask?.cancel()
        handshakeTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(AppConstants.handshakeTimeout))
            guard !Task.isCancelled else { return }
            await self?.handshakeFinished(slot: slot)
        }
    }

    /// Called by GridViewModel whenever a slot leaves the connecting state
    /// (reaches playing / error / stopped / idle). Releases the handshake
    /// slot and starts the next queued connect if any.
    func handshakeFinished(slot: Int) {
        guard handshakeInFlight else { return }
        handshakeInFlight = false
        handshakeTimeoutTask?.cancel()
        handshakeTimeoutTask = nil

        guard !pendingConnects.isEmpty else { return }
        let next = pendingConnects.removeFirst()
        beginHandshake(slot: next.slot, url: next.url, bufferDuration: next.bufferDuration)
    }

    func stopStream(slot: Int) {
        cancelReconnect(slot: slot)
        pendingConnects.removeAll { $0.slot == slot }
        players[slot]?.stop()
    }

    func stopAll() {
        for (slot, _) in players {
            cancelReconnect(slot: slot)
        }
        pendingConnects.removeAll()
        for player in players.values {
            player.stop()
        }
    }

    func removePlayer(slot: Int) {
        cancelReconnect(slot: slot)
        pendingConnects.removeAll { $0.slot == slot }
        players[slot]?.stop()
        players.removeValue(forKey: slot)
    }

    func removeAll() {
        for (slot, _) in players {
            cancelReconnect(slot: slot)
        }
        pendingConnects.removeAll()
        handshakeInFlight = false
        handshakeTimeoutTask?.cancel()
        handshakeTimeoutTask = nil
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

        // Add small random jitter so several slots that entered error state
        // at the same moment don't re-align phase on retry.
        let base = AppConstants.reconnectBaseDelay * pow(AppConstants.reconnectBackoffMultiplier, Double(attempt))
        let jitter = Double.random(in: 0..<0.5)
        let delay = min(base + jitter, AppConstants.reconnectMaxDelay)

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
