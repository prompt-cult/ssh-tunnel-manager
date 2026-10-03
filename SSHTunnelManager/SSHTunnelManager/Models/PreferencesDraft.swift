import Foundation
import Observation

@Observable
@MainActor
final class PreferencesDraft {
    var defaultServicePort: Int
    var maxAllocatedPort: Int
    var findNextHighPort: Bool
    var isLocked: Bool

    init() {
        self.defaultServicePort = AppPreferences.defaultServicePort
        self.maxAllocatedPort = AppPreferences.maxAllocatedPort
        self.findNextHighPort = AppPreferences.findNextHighPort
        self.isLocked = true // Always resets to locked upon opening
    }

    func updateDefaultServicePort(_ port: Int) {
        defaultServicePort = port
        if isLocked {
            maxAllocatedPort = port
        }
    }

    func updateMaxAllocatedPort(_ port: Int) {
        maxAllocatedPort = port
        if isLocked {
            defaultServicePort = port
        }
    }

    func toggleLock() {
        isLocked.toggle()
        if isLocked {
            let reconciled = max(defaultServicePort, maxAllocatedPort)
            defaultServicePort = reconciled
            maxAllocatedPort = reconciled
        }
    }

    func commit() {
        AppPreferences.findNextHighPort = findNextHighPort
        AppPreferences.defaultServicePort = defaultServicePort
        AppPreferences.maxAllocatedPort = maxAllocatedPort
        AppPreferences.hasCompletedFirstLaunch = true
    }
}
