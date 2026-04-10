import SwiftUI
import SwiftData

// MARK: - Navigation Destination

enum AppDestination: Hashable {
    case dashboard(UUID)
    case cameras
}

#if os(macOS)
struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedDestination: AppDestination?
    @Query(sort: \Dashboard.createdAt) private var dashboards: [Dashboard]

    let onlineCount: Int
    let onAddCamera: () -> Void

    @State private var renamingDashboard: Dashboard?
    @State private var renameText = ""
    @State private var showDeleteAlert = false
    @State private var dashboardToDelete: Dashboard?
    @State private var showSettings = false

    var body: some View {
        List(selection: $selectedDestination) {
            // Header
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LotaView")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.dsOnSurface)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.dsTertiary)
                            .frame(width: 6, height: 6)
                        Text("sidebar.streamsActive \(onlineCount)")
                            .font(.system(size: 10, weight: .medium))
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundStyle(Color.dsOnSurfaceVariant)
                    }
                }
                .listRowBackground(Color.clear)
                .padding(.vertical, 4)
            }

            // Dashboards
            Section(String(localized: "sidebar.dashboards")) {
                ForEach(dashboards, id: \.id) { dashboard in
                    Label(dashboard.name, systemImage: "rectangle.split.2x2")
                        .tag(AppDestination.dashboard(dashboard.id))
                        .contextMenu {
                            Button(String(localized: "dashboard.rename")) {
                                renameText = dashboard.name
                                renamingDashboard = dashboard
                            }
                            Button(String(localized: "action.delete"), role: .destructive) {
                                dashboardToDelete = dashboard
                                showDeleteAlert = true
                            }
                        }
                }

                Button(action: addDashboard) {
                    Label("dashboard.add", systemImage: "plus.circle")
                        .foregroundStyle(Color.dsPrimary)
                }
            }

            // Camera Management
            Section {
                Label("nav.cameras", systemImage: "list.bullet.rectangle")
                    .tag(AppDestination.cameras)
            }

            // Footer
            Section {
                Button(action: onAddCamera) {
                    Label("camera.add", systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.dsPrimary)
                }

                Button { showSettings = true } label: {
                    Label("settings.title", systemImage: "gearshape")
                        .foregroundStyle(Color.dsOnSurfaceVariant)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color.dsSurfaceLow.opacity(0.8))
        .navigationTitle("")
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 280)
        .alert("dashboard.rename", isPresented: .init(
            get: { renamingDashboard != nil },
            set: { if !$0 { renamingDashboard = nil } }
        )) {
            TextField("dashboard.name", text: $renameText)
            Button("action.save") {
                if let db = renamingDashboard, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                    db.name = renameText.trimmingCharacters(in: .whitespaces)
                    db.updatedAt = Date()
                    try? modelContext.save()
                }
                renamingDashboard = nil
            }
            Button("action.cancel", role: .cancel) { renamingDashboard = nil }
        }
        .alert("dashboard.delete", isPresented: $showDeleteAlert) {
            Button("action.delete", role: .destructive) {
                if let db = dashboardToDelete {
                    // If this was selected, clear selection
                    if case .dashboard(let id) = selectedDestination, id == db.id {
                        selectedDestination = nil
                    }
                    modelContext.delete(db)
                    try? modelContext.save()
                }
                dashboardToDelete = nil
            }
            Button("action.cancel", role: .cancel) { dashboardToDelete = nil }
        } message: {
            Text("dashboard.delete.confirm")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private func addDashboard() {
        let dashboard = Dashboard(
            name: String(localized: "dashboard.defaultName")
        )
        modelContext.insert(dashboard)
        try? modelContext.save()
        selectedDestination = .dashboard(dashboard.id)
    }
}
#endif

// MARK: - iOS Dashboard Picker (used in TabView)

struct DashboardPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Dashboard.createdAt) private var dashboards: [Dashboard]
    @Binding var selectedDashboardID: UUID?

    @State private var showAddAlert = false
    @State private var newName = ""

    var body: some View {
        Menu {
            ForEach(dashboards, id: \.id) { dashboard in
                Button {
                    selectedDashboardID = dashboard.id
                } label: {
                    HStack {
                        Text(dashboard.name)
                        if dashboard.id == selectedDashboardID {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            Button {
                newName = String(localized: "dashboard.defaultName")
                showAddAlert = true
            } label: {
                Label("dashboard.add", systemImage: "plus")
            }
        } label: {
            HStack(spacing: 4) {
                Text(currentDashboardName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.dsOnSurface)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.dsOnSurfaceVariant)
            }
        }
        .alert("dashboard.add", isPresented: $showAddAlert) {
            TextField("dashboard.name", text: $newName)
            Button("action.save") { addDashboard() }
            Button("action.cancel", role: .cancel) {}
        }
    }

    private var currentDashboardName: String {
        dashboards.first { $0.id == selectedDashboardID }?.name
            ?? String(localized: "dashboard.title")
    }

    private func addDashboard() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let db = Dashboard(name: trimmed)
        modelContext.insert(db)
        try? modelContext.save()
        selectedDashboardID = db.id
    }
}
