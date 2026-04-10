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

                    // Auto-reconnect only on error (not user-initiated stop)
                    if case .error = status {
                        guard let cam = self.slotCameras[slot] else { return }
                        let reconnectURL = cam.authenticatedURL
                        await self.engine.scheduleReconnect(slot: slot, url: reconnectURL)
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
        for slot in slotCameras.keys.sorted() {
            startStream(slot: slot)
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
        fullscreenSlot = nil
    }

    func enterFullscreen(slot: Int) {
        fullscreenSlot = slot
    }

    func exitFullscreen() {
        fullscreenSlot = nil
    }

    /// Load cameras from a dashboard into sequential slots
    func loadDashboard(_ dashboard: Dashboard, allCameras: [Camera]) {
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
