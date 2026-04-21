import SwiftUI
import SwiftData

@main
struct LotaViewApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([Camera.self, Dashboard.self])
        let storeURL = Self.resolveStoreURL()
        Self.migrateLegacyDefaultStoreIfNeeded(to: storeURL)

        let config = ModelConfiguration(schema: schema, url: storeURL)

        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("[LotaView] ModelContainer failed: \(error). Backing up old DB and recreating.")

            let fm = FileManager.default
            let backupSuffix = ".backup-\(Int(Date().timeIntervalSince1970))"
            for ext in ["", "-shm", "-wal"] {
                let src = URL(fileURLWithPath: storeURL.path + ext)
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

    /// App-owned store path. Explicit to avoid the default
    /// `~/Library/Application Support/default.store`, which is
    /// shared with any other non-sandboxed SwiftData process.
    private static func resolveStoreURL() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("LotaView", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("LotaView.store")
    }

    /// One-time migration: if the new app-owned store does not yet exist but
    /// the legacy shared `default.store` does, move it (plus -wal/-shm) so
    /// existing users keep their data on upgrade.
    private static func migrateLegacyDefaultStoreIfNeeded(to newURL: URL) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: newURL.path) else { return }

        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let legacy = base.appendingPathComponent("default.store")
        guard fm.fileExists(atPath: legacy.path) else { return }

        for ext in ["", "-shm", "-wal"] {
            let src = URL(fileURLWithPath: legacy.path + ext)
            let dst = URL(fileURLWithPath: newURL.path + ext)
            if fm.fileExists(atPath: src.path) {
                try? fm.moveItem(at: src, to: dst)
            }
        }
        print("[LotaView] Migrated legacy default.store to \(newURL.path)")
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
