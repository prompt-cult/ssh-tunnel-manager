import Foundation

struct PortAllocationResult: Equatable {
    let localPort: Int
    let candidateFrontier: Int
}

enum PortAllocator {
    /// Returns nil only when every port in [minPort, maxPort] is occupied.
    static func allocate(
        servicePort: Int,
        findNextHighPort: Bool,
        frontier: Int,
        occupiedLocalPorts: Set<Int>
    ) -> PortAllocationResult? {
        guard findNextHighPort else {
            return PortAllocationResult(localPort: servicePort, candidateFrontier: frontier)
        }

        let baseline = max(frontier, occupiedLocalPorts.max() ?? frontier)
        var candidate = baseline + 1
        while candidate <= AppPreferences.maxPort {
            if !occupiedLocalPorts.contains(candidate) {
                return PortAllocationResult(localPort: candidate, candidateFrontier: candidate)
            }
            candidate += 1
        }

        // Primary scan exhausted: wrap to the lowest available port. The scan
        // is inclusive of the frontier itself, which may be occupied.
        var fallback = AppPreferences.minPort
        while fallback <= AppPreferences.maxPort {
            if !occupiedLocalPorts.contains(fallback) {
                return PortAllocationResult(localPort: fallback, candidateFrontier: frontier)
            }
            fallback += 1
        }

        return nil
    }
}
