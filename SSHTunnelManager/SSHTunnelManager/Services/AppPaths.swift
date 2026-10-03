import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "SSHTunnelManager",
    category: "AppPaths"
)

enum AppPaths {
    static let appSupportDirectory: URL = {
        // No force-unwrap: degrade to a temporary directory with a loud
        // diagnostic rather than crashing if the lookup fails.
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            let fallback = FileManager.default.temporaryDirectory
                .appendingPathComponent("SSHTunnelManager", isDirectory: true)
            logger.fault("Application Support directory unavailable; falling back to \(fallback.path, privacy: .public)")
            return fallback
        }

        let appFolder = base.appendingPathComponent("SSHTunnelManager", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        } catch {
            // Surface creation failures (permissions, disk full) instead of
            // swallowing them — downstream socket/bind and config writes will
            // also fail, and this log is the root-cause breadcrumb.
            logger.error("Failed to create app support directory at \(appFolder.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
        return appFolder
    }()

    static var tunnelsConfigFile: URL {
        appSupportDirectory.appendingPathComponent("tunnels.json")
    }

    static var activePidsFile: URL {
        appSupportDirectory.appendingPathComponent("active_pids.txt")
    }

    static var controlSocket: URL {
        appSupportDirectory.appendingPathComponent("tunnel-manager.sock")
    }
}
