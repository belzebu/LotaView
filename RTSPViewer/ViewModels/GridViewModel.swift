import SwiftUI
import SwiftData

@MainActor
@Observable
final class GridViewModel {
    private(set) var slotStatus: [Int: StreamStatus] = [:]
    private(set) var slotCameras: [Int: Camera] = [:]
    private(set) var slotPlayers: [Int: PlayerWrapper] = [:]
    var fullscreenSlot: Int? = nil

    private let engine = StreamEngine()
    private var playerDelegates: [Int: SlotDelegate] = [:]
    private var reconnectAttempts: [Int: Int] = [:]

    var isFullscreen: Bool { fullscreenSlot != nil }

    /// Current grid layout based on assigned camera count
    var layout: GridLayout {
        GridLayout.forCount(slotCameras.count)
    }

    func assignCamera(_ camera: Camera, to slot: Int) {
        guard slot >= 0, slot < AppConstants.maxGridSlots else { return }
        Task { await engine.stopStream(slot: slot) }
        slotCameras[slot] = camera
        slotStatus[slot] = .idle
    }

    func removeCamera(from slot: Int) {
        Task { await engine.removePlayer(slot: slot) }
        slotCameras.removeValue(forKey: slot)
        slotStatus.removeValue(forKey: slot)
        slotPlayers.removeValue(forKey: slot)
        playerDelegates.removeValue(forKey: slot)
    }

    func startStream(slot: Int) {
        guard let camera = slotCameras[slot] else { return }
        let url = camera.authenticatedURL
        slotStatus[slot] = .connecting

        Task {
            let player = await engine.createPlayer(for: slot)

            let delegate = SlotDelegate(slot: slot) { [weak self] slot, status in
                Task { @MainActor in
                    guard let self else { return }
                    self.slotStatus[slot] = status

                    // Any transition out of `.connecting` means the handshake
                    // is done; release the serialized handshake slot so the
                    // next queued connect can proceed.
                    let isTerminal: Bool = switch status {
                    case .playing, .error, .stopped, .idle: true
                    case .connecting: false
                    }
                    if isTerminal {
                        await self.engine.handshakeFinished(slot: slot)
                    }

                    // Reset attempt counter on successful play so next disconnect
                    // starts backoff from zero again.
                    if case .playing = status {
                        self.reconnectAttempts[slot] = 0
                        return
                    }

                    // Auto-reconnect only on error (not user-initiated stop).
                    // Use real exponential backoff keyed per slot so a flood of
                    // errors doesn't hammer the server every second.
                    if case .error = status {
                        guard let cam = self.slotCameras[slot] else { return }
                        let reconnectURL = cam.authenticatedURL
                        let attempt = self.reconnectAttempts[slot] ?? 0
                        self.reconnectAttempts[slot] = attempt + 1
                        await self.engine.scheduleReconnect(
                            slot: slot,
                            url: reconnectURL,
                            attempt: attempt
                        )
                    }
                }
            }
            playerDelegates[slot] = delegate
            player.delegate = delegate
            slotPlayers[slot] = player

            await engine.startStream(slot: slot, url: url)
        }
    }

    func stopStream(slot: Int) {
        Task { await engine.stopStream(slot: slot) }
        slotStatus[slot] = .stopped
    }

    func startAllStreams() {
        // Stagger initial connections so we don't open N parallel TCP sockets
        // to the same NVR in the same millisecond — most consumer NVRs have a
        // concurrent-session cap and will RST the overflow.
        let sorted = slotCameras.keys.sorted()
        for (index, slot) in sorted.enumerated() {
            let delay = Double(index) * AppConstants.staggerStartDelay
            if delay == 0 {
                startStream(slot: slot)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.startStream(slot: slot)
                }
            }
        }
    }

    func stopAllStreams() {
        Task { await engine.stopAll() }
        for slot in slotCameras.keys {
            slotStatus[slot] = .stopped
        }
    }

    func resetAll() {
        Task { await engine.removeAll() }
        slotCameras.removeAll()
        slotStatus.removeAll()
        slotPlayers.removeAll()
        playerDelegates.removeAll()
        reconnectAttempts.removeAll()
        fullscreenSlot = nil
    }

    func enterFullscreen(slot: Int) {
        fullscreenSlot = slot
    }

    func exitFullscreen() {
        fullscreenSlot = nil
    }

    /// Load cameras from a dashboard into sequential slots.
    ///
    /// SwiftUI's lifecycle fires multiple triggers on startup (RootView.onAppear,
    /// onChange of selectedDestination, LiveDashboardView.onAppear, onChange of
    /// cameraIDs) — without this guard, each one tears down & restarts every
    /// stream, causing the engine's serialization to be bypassed by parallel
    /// re-entrant Tasks.
    func loadDashboard(_ dashboard: Dashboard, allCameras: [Camera]) {
        let desired = dashboard.cameras(from: allCameras)
            .prefix(AppConstants.maxGridSlots)
            .map { $0.id }
        let current = (0..<AppConstants.maxGridSlots)
            .compactMap { slotCameras[$0]?.id }

        if desired == current {
            return
        }

        resetAll()
        let cameras = dashboard.cameras(from: allCameras)
        for (index, camera) in cameras.prefix(AppConstants.maxGridSlots).enumerated() {
            assignCamera(camera, to: index)
        }
        startAllStreams()
    }
}

// MARK: - Slot Delegate

private final class SlotDelegate: NSObject, PlayerWrapperDelegate {
    let slot: Int
    let onStatusChange: (Int, StreamStatus) -> Void

    init(slot: Int, onStatusChange: @escaping (Int, StreamStatus) -> Void) {
        self.slot = slot
        self.onStatusChange = onStatusChange
    }

    func playerDidChangeState(_ wrapper: PlayerWrapper, state: StreamStatus) {
        onStatusChange(slot, state)
    }
}
