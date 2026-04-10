import SwiftUI
import SwiftData

@main
struct LotaViewApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([Camera.self, Dashboard.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // If schema migration fails, delete and recreate
            let url = config.url
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("store-shm"))
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("store-wal"))
            container = try! ModelContainer(for: schema, configurations: [config])
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        #endif
    }
}
