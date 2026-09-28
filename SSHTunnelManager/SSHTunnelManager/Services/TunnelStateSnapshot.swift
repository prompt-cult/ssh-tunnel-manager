import Foundation

struct TunnelSnapshot: Codable, Sendable {
    let id: String
    let name: String
    let host: String
    let port: Int
    let status: String
    let portMappings: [PortMappingSnapshot]
    let lastError: String?
    let pid: Int32?
}

struct PortMappingSnapshot: Codable, Sendable {
    let id: String
    let forward: String
    let localHost: String
    let localPort: Int
    let remoteHost: String
    let remotePort: Int

    init(mapping: PortMapping) {
        self.id = mapping.id.uuidString
        self.forward = mapping.forward.rawValue
        self.localHost = mapping.localHost
        self.localPort = mapping.localPort
        self.remoteHost = mapping.remoteHost
        self.remotePort = mapping.remotePort
    }
}

struct SystemStatusSnapshot: Codable, Sendable {
    let version: String
    let totalTunnels: Int
    let activeTunnels: Int
    let defaultServicePort: Int
    let maxAllocatedPort: Int
    let findNextHighPort: Bool
}

@MainActor
protocol TunnelStateProvider: AnyObject, Sendable {
    func systemStatusSnapshot() -> SystemStatusSnapshot
    func tunnelSnapshots() -> [TunnelSnapshot]
}
