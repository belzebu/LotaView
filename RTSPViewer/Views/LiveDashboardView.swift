import SwiftUI
import SwiftData

struct LiveDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var gridVM: GridViewModel
    @Query(sort: \Camera.createdAt) private var allCameras: [Camera]

    let dashboard: Dashboard?
    let onAddCamera: () -> Void
    let onEditDashboard: () -> Void

    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()

            if let fullscreenSlot = gridVM.fullscreenSlot {
                FullscreenPlayerView(
                    slot: fullscreenSlot,
                    camera: gridVM.slotCameras[fullscreenSlot],
                    status: gridVM.slotStatus[fullscreenSlot],
                    player: gridVM.slotPlayers[fullscreenSlot],
                    onDismiss: { gridVM.exitFullscreen() }
                )
            } else {
                VStack(spacing: 0) {
                    headerBar
                    if gridVM.slotCameras.isEmpty {
                        emptyState
                    } else {
                        gridContent
                    }
                }
            }
        }
        .onChange(of: dashboard?.cameraIDs) {
            reloadFromDashboard()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dashboard?.name ?? String(localized: "dashboard.title"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.dsOnSurface)

            }

            Spacer()

            HStack(spacing: 8) {
                // Edit dashboard cameras
                if dashboard != nil {
                    Button(action: onEditDashboard) {
                        Image(systemName: "square.grid.2x2")
                            .font(.body)
                            .foregroundStyle(Color.dsPrimary)
                            .padding(8)
                            .background(Color.dsSurfaceHigh)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }

                // Play/Stop toggle
                Button {
                    let hasActive = gridVM.slotStatus.values.contains { $0.isActive }
                    if hasActive {
                        gridVM.stopAllStreams()
                    } else {
                        gridVM.startAllStreams()
                    }
                } label: {
                    let hasActive = gridVM.slotStatus.values.contains { $0.isActive }
                    Image(systemName: hasActive ? "stop.fill" : "play.fill")
                        .font(.body)
                        .foregroundStyle(Color.dsPrimary)
                        .padding(8)
                        .background(Color.dsSurfaceHigh)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                // Add camera
                Button(action: onAddCamera) {
                    Image(systemName: "plus")
                        .font(.body)
                        .foregroundStyle(Color.dsPrimary)
                        .padding(8)
                        .background(Color.dsSurfaceHigh)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "rectangle.split.2x2")
                .font(.system(size: 48))
                .foregroundStyle(Color.dsOnSurfaceVariant.opacity(0.3))
            Text("dashboard.empty")
                .font(.headline)
                .foregroundStyle(Color.dsOnSurface)
            Text("dashboard.empty.hint")
                .font(.subheadline)
                .foregroundStyle(Color.dsOnSurfaceVariant)
            if dashboard != nil {
                Button(action: onEditDashboard) {
                    Text("dashboard.editCameras")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.dsOnPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.dsPrimaryContainer)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Dynamic Grid

    private var gridContent: some View {
        GeometryReader { geo in
            let layout = gridVM.layout
            let spacing: CGFloat = 8
            let hPad: CGFloat = 16
            let vPad: CGFloat = 8
            let totalHSpacing = spacing * CGFloat(layout.columns - 1)
            let totalVSpacing = spacing * CGFloat(layout.rows - 1)
            let cellWidth = (geo.size.width - totalHSpacing - hPad * 2) / CGFloat(layout.columns)
            let cellHeight = (geo.size.height - totalVSpacing - vPad * 2) / CGFloat(layout.rows)

            VStack(spacing: spacing) {
                ForEach(0..<layout.rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<layout.columns, id: \.self) { col in
                            let slot = row * layout.columns + col
                            if slot < gridVM.slotCameras.count {
                                StreamCellView(
                                    slot: slot,
                                    camera: gridVM.slotCameras[slot],
                                    status: gridVM.slotStatus[slot],
                                    player: gridVM.slotPlayers[slot],
                                    onTap: { gridVM.enterFullscreen(slot: slot) },
                                    onAssign: {}
                                )
                                .frame(width: cellWidth, height: cellHeight)
                            } else {
                                Color.clear
                                    .frame(width: cellWidth, height: cellHeight)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, hPad)
            .padding(.vertical, vPad)
        }
    }

    // MARK: - Helpers

    private func reloadFromDashboard() {
        guard let dashboard else { return }
        gridVM.loadDashboard(dashboard, allCameras: allCameras)
    }
}

// MARK: - Int Identifiable

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}
