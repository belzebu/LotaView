import SwiftUI

struct StreamCellView: View {
    let slot: Int
    let camera: Camera?
    let status: StreamStatus?
    let player: PlayerWrapper?
    let onTap: () -> Void
    let onAssign: () -> Void

    @State private var isHovering = false

    var body: some View {
        ZStack {
            if camera != nil {
                filledCell
            } else {
                emptyCell
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.dsOutlineVariant.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.dsOnSurface.opacity(0.12), radius: 8, y: 4)
        .onHover { isHovering = $0 }
    }

    // MARK: - Filled Cell

    private var filledCell: some View {
        ZStack(alignment: .bottom) {
            // Video stream — id forces SwiftUI to recreate when player changes
            StreamPlayerView(player: player)
                .id(player?.playerID)

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.4), .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Bottom info bar
            VStack(alignment: .leading, spacing: 6) {
                Spacer()

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        // LIVE badge
                        HStack(spacing: 4) {
                            Circle()
                                .fill(statusDotColor)
                                .frame(width: 6, height: 6)

                            Text(statusBadgeText)
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.5)
                                .textCase(.uppercase)
                                .foregroundStyle(.white.opacity(0.9))
                        }

                        // Camera name
                        Text(camera?.name ?? "")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    // Hover actions
                    if isHovering {
                        HStack(spacing: 6) {
                            cellActionButton(icon: "arrow.up.left.and.arrow.down.right", action: onTap)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
            }
            .padding(14)
        }
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    // MARK: - Empty Cell

    private var emptyCell: some View {
        Button(action: onAssign) {
            VStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.dsOnSurfaceVariant.opacity(0.5))

                Text("camera.add")
                    .font(.system(size: 11, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(Color.dsOnSurfaceVariant.opacity(0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.dsSurfaceHigh)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var statusDotColor: Color {
        switch status {
        case .playing: .red
        case .connecting: .orange
        case .error: Color.dsError
        default: .gray
        }
    }

    private var statusBadgeText: String {
        switch status {
        case .playing: String(localized: "status.live")
        case .connecting: String(localized: "status.connecting")
        case .error: String(localized: "status.error")
        default: String(localized: "status.offline")
        }
    }

    private func cellActionButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .padding(8)
                .background(.white.opacity(0.1))
                .background(.ultraThinMaterial.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
