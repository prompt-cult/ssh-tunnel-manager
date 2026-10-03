import Foundation

struct RpcRequest: Decodable {
    let id: String
    let method: String
}

struct RpcErrorPayload: Codable {
    let code: Int
    let message: String
}

struct RpcResponse<T: Codable>: Codable {
    let id: String
    let result: T?
    let error: RpcErrorPayload?

    init(id: String, result: T) {
        self.id = id
        self.result = result
        self.error = nil
    }

    init(id: String, errorCode: Int, message: String) {
        self.id = id
        self.result = nil
        self.error = RpcErrorPayload(code: errorCode, message: message)
    }
}

struct DescribeResult: Codable {
    let version: String
    let methods: [String]
    let schema: String
}

struct TunnelListResult: Codable {
    let tunnels: [TunnelSnapshot]
}

enum ControlProtocol {
    @MainActor
    static func handleLine(_ line: String, provider: TunnelStateProvider) -> String {
        guard let data = line.data(using: .utf8) else {
            return encodeError(id: "null", code: -32700, message: "Invalid UTF-8")
        }

        guard let request = try? JSONDecoder().decode(RpcRequest.self, from: data) else {
            return encodeError(id: "null", code: -32600, message: "Invalid Request")
        }

        switch request.method {
        case "describe":
            let result = DescribeResult(
                version: "1.0.0",
                methods: ["describe", "get_status", "list_tunnels"],
                schema: "control-v1.jtd.json"
            )
            return encodeResponse(id: request.id, result: result)

        case "get_status":
            let snapshot = provider.systemStatusSnapshot()
            return encodeResponse(id: request.id, result: snapshot)

        case "list_tunnels":
            let list = TunnelListResult(tunnels: provider.tunnelSnapshots())
            return encodeResponse(id: request.id, result: list)

        default:
            return encodeError(id: request.id, code: -32601, message: "Method not found: \(request.method)")
        }
    }

    private static func encodeResponse<T: Codable>(id: String, result: T) -> String {
        let resp = RpcResponse(id: id, result: result)
        if let data = try? JSONEncoder().encode(resp),
           let str = String(data: data, encoding: .utf8) {
            return str + "\n"
        }
        return encodeError(id: id, code: -32603, message: "Internal JSON serialization error")
    }

    private static func encodeError(id: String, code: Int, message: String) -> String {
        let resp = RpcResponse<String>(id: id, errorCode: code, message: message)
        if let data = try? JSONEncoder().encode(resp),
           let str = String(data: data, encoding: .utf8) {
            return str + "\n"
        }
        // Last-resort fallback: emit a fixed frame. Interpolating the raw
        // client-supplied id/message here could produce malformed JSON or
        // inject fields — precisely what the fallback must never do.
        return "{\"id\":\"null\",\"error\":{\"code\":-32603,\"message\":\"internal error\"}}\n"
    }
}
