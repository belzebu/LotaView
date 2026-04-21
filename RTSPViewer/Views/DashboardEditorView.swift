import SwiftUI
import SwiftData

struct DashboardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var dashboard: Dashboard
    @Query(sort: \Camera.createdAt) private var allCameras: [Camera]
    @State private var dashboardName: String = ""
    @State private var selectedIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dsBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        nameField
                        cameraSelection
                    }
                    .padding(20)
                }
            }
            .navigationTitle(String(localized: "dashboard.edit"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) { save() }
                        .disabled(dashboardName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                dashboardName = dashboard.name

                // Auto-heal dashboards that still reference cameras that were
                // deleted before the cascade fix — otherwise the "N/9" counter
                // and downstream logic count orphan UUIDs.
                let validIDs = Set(allCameras.map(\.id))
                let cleaned = dashboard.cameraIDs.filter { validIDs.contains($0) }
                if cleaned.count != dashboard.cameraIDs.count {
                    dashboard.cameraIDs = cleaned
                    try? modelContext.save()
                }

                selectedIDs = Set(dashboard.cameraIDs)
            }
        }
    }

    // MARK: - Name

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("dashboard.name")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.dsOnSurfaceVariant)

            TextField(String(localized: "dashboard.name.placeholder"), text: $dashboardName)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.dsSurfaceHighest)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(Color.dsOnSurface)
        }
    }

    // MARK: - Camera Selection

    private var cameraSelection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("dashboard.selectCameras")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.dsOnSurfaceVariant)

                Spacer()

                Text("\(selectedIDs.count)/\(AppConstants.maxGridSlots)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.dsOnSurfaceVariant)
            }

            if allCameras.isEmpty {
                Text("camera.none")
                    .font(.subheadline)
                    .foregroundStyle(Color.dsOnSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 2) {
                    ForEach(allCameras, id: \.id) { camera in
                        cameraRow(camera)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func cameraRow(_ camera: Camera) -> some View {
        let isSelected = selectedIDs.contains(camera.id)
        let atLimit = selectedIDs.count >= AppConstants.maxGridSlots && !isSelected

        return Button {
            if isSelected {
                selectedIDs.remove(camera.id)
            } else if !atLimit {
                selectedIDs.insert(camera.id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Color.dsPrimary : Color.dsOnSurfaceVariant.opacity(0.4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(camera.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dsOnSurface)
                    Text(camera.rtspURL)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.dsOnSurfaceVariant)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(12)
            .background(isSelected ? Color.dsPrimary.opacity(0.08) : Color.dsSurfaceHigh.opacity(0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(atLimit ? 0.4 : 1)
    }

    // MARK: - Save

    private func save() {
        let trimmed = dashboardName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        dashboard.name = trimmed
        // Preserve insertion order: keep existing order, append new ones
        let existingOrdered = dashboard.cameraIDs.filter { selectedIDs.contains($0) }
        let newOnes = selectedIDs.subtracting(Set(existingOrdered))
        dashboard.cameraIDs = existingOrdered + Array(newOnes)
        dashboard.updatedAt = Date()

        try? modelContext.save()
        dismiss()
    }
}
