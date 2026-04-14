import SwiftUI
import SwiftData

@main
struct LotaViewApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([Camera.self, Dashboard.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)

        // Try opening existing store first.
        // If the schema changed, back up the old DB before recreating,
        // so user data isn't silently destroyed.
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("[LotaView] ModelContainer failed: \(error). Backing up old DB and recreating.")

            let url = config.url
            let fm = FileManager.default
            let backupSuffix = ".backup-\(Int(Date().timeIntervalSince1970))"

            // Move old files to backups instead of deleting
            for ext in ["", ".store-shm", ".store-wal"] {
                let src = ext.isEmpty ? url : url.deletingPathExtension().appendingPathExtension(String(ext.dropFirst()))
                if fm.fileExists(atPath: src.path) {
                    let dst = URL(fileURLWithPath: src.path + backupSuffix)
                    try? fm.moveItem(at: src, to: dst)
                }
            }

            do {
                container = try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("[LotaView] Cannot create ModelContainer even after reset: \(error)")
            }
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
