import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appearance") private var appearanceMode: Int = AppearanceMode.system.rawValue
    @State private var gridVM = GridViewModel()
    @State private var cameraVM = CameraManagerViewModel()
    @Query(sort: \Camera.createdAt) private var allCameras: [Camera]
    @Query(sort: \Dashboard.createdAt) private var allDashboards: [Dashboard]

    // Navigation state
    #if os(macOS)
    @State private var selectedDestination: AppDestination? = nil
    #endif
    @State private var selectedDashboardID: UUID?
    @State private var selectedTab: AppTab = .liveView
    @State private var editingDashboard: Dashboard?

    var body: some View {
        Group {
            #if os(macOS)
            macOSLayout
            #else
            iOSLayout
            #endif
        }
        .preferredColorScheme(
            (AppearanceMode(rawValue: appearanceMode) ?? .system).colorScheme
        )
        .onAppear {
            cameraVM.setModelContext(modelContext)
            ensureDefaultDashboard()
            loadInitialDashboard()
        }
        .sheet(isPresented: $cameraVM.showingForm) {
            cameraVM.fetchCameras()
        } content: {
            CameraFormSheet(camera: cameraVM.editingCamera, viewModel: cameraVM)
        }
        .sheet(item: $editingDashboard) { dashboard in
            DashboardEditorView(dashboard: dashboard)
        }
    }

    // MARK: - macOS

    #if os(macOS)
    private var macOSLayout: some View {
        NavigationSplitView {
            SidebarView(
                selectedDestination: $selectedDestination,
                onlineCount: onlineCount,
                onAddCamera: { cameraVM.startAdding() }
            )
        } detail: {
            Group {
                switch selectedDestination {
                case .dashboard(let id):
                    if let dashboard = allDashboards.first(where: { $0.id == id }) {
                        LiveDashboardView(
                            gridVM: gridVM,
                            dashboard: dashboard,
                            onAddCamera: { cameraVM.startAdding() },
                            onEditDashboard: { editingDashboard = dashboard }
                        )
                        .id(id)
                        .onAppear { gridVM.loadDashboard(dashboard, allCameras: allCameras) }
                    }
                case .cameras:
                    CameraManagementView(
                        viewModel: cameraVM,
                        gridVM: gridVM,
                        cameras: allCameras
                    )
                case nil:
                    emptyDetailView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.dsBackground)
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selectedDestination) { _, newValue in
            if case .dashboard(let id) = newValue,
               let dashboard = allDashboards.first(where: { $0.id == id }) {
                gridVM.loadDashboard(dashboard, allCameras: allCameras)
            }
        }
    }
    #endif

    // MARK: - iOS

    #if os(iOS)
    private var iOSLayout: some View {
        TabView(selection: $selectedTab) {
            iOSLiveView
                .tabItem { Label("nav.liveView", systemImage: "video.fill") }
                .tag(AppTab.liveView)

            CameraManagementView(viewModel: cameraVM, gridVM: gridVM, cameras: allCameras)
                .tabItem { Label("nav.cameras", systemImage: "list.bullet.rectangle") }
                .tag(AppTab.cameras)

            SettingsView()
                .tabItem { Label("settings.title", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(Color.dsPrimary)
    }

    private var iOSLiveView: some View {
        NavigationStack {
            LiveDashboardView(
                gridVM: gridVM,
                dashboard: selectedDashboard,
                onAddCamera: { cameraVM.startAdding() },
                onEditDashboard: {
                    if let db = selectedDashboard { editingDashboard = db }
                }
            )
            .toolbar {
                ToolbarItem(placement: .principal) {
                    DashboardPickerView(selectedDashboardID: $selectedDashboardID)
                }
            }
        }
        .onChange(of: selectedDashboardID) {
            if let db = selectedDashboard {
                gridVM.loadDashboard(db, allCameras: allCameras)
            }
        }
    }
    #endif

    // MARK: - Helpers

    private var emptyDetailView: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.split.2x2")
                .font(.system(size: 48))
                .foregroundStyle(Color.dsOnSurfaceVariant.opacity(0.3))
            Text("dashboard.selectHint")
                .font(.headline)
                .foregroundStyle(Color.dsOnSurfaceVariant)
        }
    }

    private var selectedDashboard: Dashboard? {
        allDashboards.first { $0.id == selectedDashboardID }
    }

    private var onlineCount: Int {
        gridVM.slotStatus.values.filter { $0 == .playing }.count
    }

    private func ensureDefaultDashboard() {
        if allDashboards.isEmpty {
            let defaultDB = Dashboard(name: String(localized: "dashboard.defaultName"))
            // Add all existing cameras to default dashboard
            defaultDB.cameraIDs = allCameras.map(\.id)
            modelContext.insert(defaultDB)
            try? modelContext.save()
        }
    }

    private func loadInitialDashboard() {
        guard let first = allDashboards.first else { return }

        #if os(macOS)
        if selectedDestination == nil {
            selectedDestination = .dashboard(first.id)
        }
        #endif

        if selectedDashboardID == nil {
            selectedDashboardID = first.id
            gridVM.loadDashboard(first, allCameras: allCameras)
        }
    }
}

enum AppTab: Hashable {
    case liveView
    case cameras
    case settings
}
