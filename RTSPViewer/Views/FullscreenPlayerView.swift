import SwiftUI

struct FullscreenPlayerView: View {
    let slot: Int
    let camera: Camera?
    let status: StreamStatus?
    let player: PlayerWrapper?
    let onDismiss: () -> Void

    @State private var showControls = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            StreamPlayerView(player: player)
                .ignoresSafeArea()

            // Controls overlay
            if showControls {
                controlsOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showControls)
        .onTapGesture {
            showControls.toggle()
        }
    }

    private var controlsOverlay: some View {
        VStack {
            // Top bar
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.white.opacity(0.1))
                        .background(.ultraThinMaterial.opacity(0.3))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding()

            Spacer()

            // Bottom info
            if let camera {
                HStack(spacing: 8) {
                    Circle()
                        .fill(status == .playing ? Color.red : Color.gray)
                        .frame(width: 8, height: 8)

                    if status == .playing {
                        Text("status.live")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Text(camera.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }
}
