import SwiftUI
import AVFoundation

#if os(iOS)
struct StreamPlayerView: UIViewRepresentable {
    let player: PlayerWrapper?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        container.clipsToBounds = true
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        attachPlayer(to: container, coordinator: context.coordinator)
    }

    final class Coordinator {
        var attachedPlayerID: UUID?
        var currentPlayerView: UIView?
    }

    private func attachPlayer(to container: UIView, coordinator: Coordinator) {
        let newID = player?.playerID

        // Skip if same player already attached
        if coordinator.attachedPlayerID != nil, coordinator.attachedPlayerID == newID { return }

        // Remove old player view
        coordinator.currentPlayerView?.removeFromSuperview()
        coordinator.currentPlayerView = nil
        coordinator.attachedPlayerID = nil

        guard let player else { return }

        let playerView = player.view
        playerView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(playerView)

        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: container.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            playerView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        coordinator.currentPlayerView = playerView
        coordinator.attachedPlayerID = newID
    }
}

#elseif os(macOS)
struct StreamPlayerView: NSViewRepresentable {
    let player: PlayerWrapper?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        attachPlayer(to: container, coordinator: context.coordinator)
    }

    final class Coordinator {
        var attachedPlayerID: UUID?
        var currentPlayerView: NSView?
    }

    private func attachPlayer(to container: NSView, coordinator: Coordinator) {
        let newID = player?.playerID

        // Skip if same player already attached
        if coordinator.attachedPlayerID != nil, coordinator.attachedPlayerID == newID { return }

        // Remove old player view
        coordinator.currentPlayerView?.removeFromSuperview()
        coordinator.currentPlayerView = nil
        coordinator.attachedPlayerID = nil

        guard let player else { return }

        let playerView = player.view
        playerView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(playerView)

        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: container.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            playerView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        coordinator.currentPlayerView = playerView
        coordinator.attachedPlayerID = newID
    }
}
#endif
