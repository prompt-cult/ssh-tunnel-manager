import Foundation

enum AppPreferences {
    static let findNextHighPortKey = "findNextHighPort"
    static let defaultServicePortKey = "defaultServicePort"
    static let maxAllocatedPortKey = "maxAllocatedPort"
    static let hasCompletedFirstLaunchKey = "hasCompletedFirstLaunch"

    static let minPort = 1024
    static let maxPort = 65535
    static let standardDefaultPort = 4096

    // Injectable so the unit-test bundle runs against an ephemeral suite
    // instead of clobbering the user's real preferences. Plain global like
    // sshProcessGroupID in TunnelManager — written once at test setup, read
    // from @MainActor code; kept off `nonisolated(unsafe)` for the Xcode 15.2
    // toolchain the release CI pins.
    static var defaults: UserDefaults = .standard

    static var findNextHighPort: Bool {
        get {
            if defaults.object(forKey: findNextHighPortKey) == nil {
                return true
            }
            return defaults.bool(forKey: findNextHighPortKey)
        }
        set {
            defaults.set(newValue, forKey: findNextHighPortKey)
        }
    }

    static var defaultServicePort: Int {
        get {
            let val = defaults.integer(forKey: defaultServicePortKey)
            if val < minPort || val > maxPort {
                return standardDefaultPort
            }
            return val
        }
        set {
            let clamped = min(max(newValue, minPort), maxPort)
            defaults.set(clamped, forKey: defaultServicePortKey)
        }
    }

    static var maxAllocatedPort: Int {
        get {
            let val = defaults.integer(forKey: maxAllocatedPortKey)
            if val < minPort || val > maxPort {
                return standardDefaultPort
            }
            return val
        }
        set {
            let clamped = min(max(newValue, minPort), maxPort)
            defaults.set(clamped, forKey: maxAllocatedPortKey)
        }
    }

    static var hasCompletedFirstLaunch: Bool {
        get {
            defaults.bool(forKey: hasCompletedFirstLaunchKey)
        }
        set {
            defaults.set(newValue, forKey: hasCompletedFirstLaunchKey)
        }
    }

    static func recordAllocatedPort(_ port: Int) {
        guard findNextHighPort else { return }
        if port >= minPort && port <= maxPort && port > maxAllocatedPort {
            maxAllocatedPort = port
        }
    }
}
