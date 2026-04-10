import SwiftUI

struct CameraManagementView: View {
    @Bindable var viewModel: CameraManagerViewModel
    let gridVM: GridViewModel
    let cameras: [Camera]

    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    statsCards
                    cameraList
                }
                .padding(20)
            }
        }
        .alert("camera.delete", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("action.delete", role: .destructive) { viewModel.performDelete() }
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text("camera.delete.confirm")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("camera.management")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.dsOnSurface)

                Text("camera.management.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(Color.dsOnSurfaceVariant)
            }

            Spacer()

            Button(action: { viewModel.startAdding() }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("camera.addNew")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color.dsOnPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.dsPrimary, Color.dsPrimaryContainer],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Stats Cards

    private var statsCards: some View {
        HStack(spacing: 12) {
            StatCard(title: String(localized: "stats.total"), value: "\(cameras.count)", color: Color.dsOnSurface)
            StatCard(title: String(localized: "stats.online"), value: "\(onlineCount)", color: Color.dsTertiary)
            StatCard(title: String(localized: "stats.errors"), value: "\(errorCount)", color: Color.dsError)
        }
    }

    private var onlineCount: Int {
        gridVM.slotStatus.values.filter { $0 == .playing }.count
    }

    private var errorCount: Int {
        gridVM.slotStatus.values.filter { if case .error = $0 { return true }; return false }.count
    }

    // MARK: - Camera List

    private var cameraList: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Text("table.status")
                    .frame(width: 60)
                Text("table.cameraDetails")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
                Text("table.rtspEndpoint")
                    .frame(width: 250, alignment: .leading)
                Text("table.actions")
                    .frame(width: 80, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .bold))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(Color.dsOnSurfaceVariant)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.dsSurfaceLow.opacity(0.5))

            Divider().background(Color.dsOutlineVariant.opacity(0.1))

            if cameras.isEmpty {
                emptyState
            } else {
                ForEach(cameras, id: \.id) { camera in
                    CameraRowView(
                        camera: camera,
                        status: cameraStatus(camera),
                        onEdit: { viewModel.startEditing(camera) },
                        onDelete: { viewModel.confirmDelete(camera) }
                    )
                    Divider().background(Color.dsOutlineVariant.opacity(0.05))
                }
            }
        }
        .background(Color.dsSurface.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.dsOutlineVariant.opacity(0.05), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(Color.dsOnSurfaceVariant.opacity(0.3))
            Text("camera.none.subtitle")
                .font(.subheadline)
                .foregroundStyle(Color.dsOnSurfaceVariant)
            Text("camera.none.hint")
                .font(.caption)
                .foregroundStyle(Color.dsOnSurfaceVariant.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func cameraStatus(_ camera: Camera) -> StreamStatus? {
        for (slot, cam) in gridVM.slotCameras {
            if cam.id == camera.id {
                return gridVM.slotStatus[slot]
            }
        }
        return nil
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.dsOnSurfaceVariant)

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .sentinelCard()
    }
}

// MARK: - Camera Row

private struct CameraRowView: View {
    let camera: Camera
    let status: StreamStatus?
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {
            // Status dot
            statusDot
                .frame(width: 60)

            // Camera details
            VStack(alignment: .leading, spacing: 2) {
                Text(camera.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isHovering ? Color.dsPrimary : Color.dsOnSurface)

                Text("ID: \(camera.id.uuidString.prefix(8))")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dsOnSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)

            // RTSP URL
            Text(camera.rtspURL)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.dsOnSurfaceVariant)
                .lineLimit(1)
                .frame(width: 250, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.dsSurfaceHighest.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // Actions
            HStack(spacing: 6) {
                if isHovering {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.dsOnSurface)
                            .padding(6)
                            .background(Color.dsSurfaceBright)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.dsError)
                            .padding(6)
                            .background(Color.dsSurfaceBright)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 80, alignment: .trailing)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .background(isHovering ? Color.dsSurfaceHigh.opacity(0.5) : .clear)
    }

    @ViewBuilder
    private var statusDot: some View {
        let isOnline = status == .playing
        let isError = {
            if case .error = status { return true }
            return false
        }()

        Circle()
            .fill(isOnline ? Color.dsTertiary : (isError ? Color.dsError.opacity(0.4) : Color.dsOnSurfaceVariant.opacity(0.3)))
            .frame(width: 10, height: 10)
            .overlay {
                if isOnline {
                    Circle()
                        .fill(Color.dsTertiary.opacity(0.3))
                        .frame(width: 16, height: 16)
                }
            }
    }
}
