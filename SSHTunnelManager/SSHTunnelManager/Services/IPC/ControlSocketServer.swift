import Foundation
import Darwin
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "SSHTunnelManager",
    category: "ControlSocketServer"
)

/// Per-connection state. All mutation of `isClosed`, the framer, and the fd
/// happens on the connection's own serial queue, so a write dispatched from a
/// @MainActor task after the peer disconnected can never touch a stale or
/// reused descriptor: the close in the cancel handler is serialized ahead of
/// it on the same queue and the closed flag suppresses the write.
private final class ControlConnection {
    let fd: Int32
    let queue: DispatchQueue
    private(set) var readSource: DispatchSourceRead?
    private var framer = LineFramer()
    private var isClosed = false
    private var fdClosed = false

    init(fd: Int32) {
        self.fd = fd
        self.queue = DispatchQueue(label: "com.sshtunnelmanager.controlconn.\(fd)", qos: .utility)
    }

    func start(provider: TunnelStateProvider?) {
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        readSource = source
        source.setEventHandler { [weak self] in
            guard let self else { return }
            var buffer = [UInt8](repeating: 0, count: 4096)
            let bytesRead = read(self.fd, &buffer, buffer.count)
            if bytesRead <= 0 {
                // 0 = peer closed (fire-and-forget CLI), < 0 = error.
                self.shutdown()
                return
            }

            let data = Data(buffer[0..<bytesRead])
            do {
                let lines = try self.framer.append(data)
                guard let provider else { return }
                for line in lines {
                    Task { @MainActor in
                        let response = ControlProtocol.handleLine(line, provider: provider)
                        self.write(response)
                    }
                }
            } catch {
                self.write("{\"id\":\"null\",\"error\":{\"code\":-32600,\"message\":\"Frame too large\"}}\n")
                self.shutdown()
            }
        }
        source.setCancelHandler { [weak self] in
            // Sole owner of close for the client fd.
            self?.closeFd()
        }
        source.resume()
    }

    /// Queued on the connection's serial queue: checks the closed flag before
    /// writing and loops until all bytes are sent or the peer errors out.
    func write(_ string: String) {
        queue.async { [weak self] in
            guard let self, !self.isClosed, let data = string.data(using: .utf8) else { return }
            var offset = 0
            while offset < data.count {
                let written = data.withUnsafeBytes { raw -> Int in
                    guard let base = raw.baseAddress else { return -1 }
                    return Darwin.write(self.fd, base.advanced(by: offset), raw.count - offset)
                }
                if written > 0 {
                    offset += written
                    continue
                }
                if errno == EINTR { continue }
                self.isClosed = true
                return
            }
        }
    }

    func shutdown() {
        queue.async { [weak self] in
            self?.isClosed = true
            self?.readSource?.cancel()
        }
    }

    private func closeFd() {
        queue.async { [weak self] in
            guard let self, !self.fdClosed else { return }
            self.fdClosed = true
            close(self.fd)
        }
    }
}

final class ControlSocketServer: @unchecked Sendable {
    private let socketURL: URL
    private weak var provider: TunnelStateProvider?
    private var listenSource: DispatchSourceRead?
    private let queue = DispatchQueue(label: "com.sshtunnelmanager.controlsocket", qos: .utility)

    init(socketURL: URL = AppPaths.controlSocket, provider: TunnelStateProvider) {
        self.socketURL = socketURL
        self.provider = provider
    }

    func start() {
        queue.async { [weak self] in
            self?.setupAndListen()
        }
    }

    private func setupAndListen() {
        let path = socketURL.path

        // Remove stale socket if exists
        unlink(path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            logger.error("Failed to create UNIX domain socket: \(errno)")
            return
        }

        // Set non-blocking
        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let maxPathLen = MemoryLayout.size(ofValue: addr.sun_path)
        guard path.utf8.count < maxPathLen else {
            logger.error("Socket path too long: \(path)")
            close(fd)
            return
        }

        _ = withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
            path.withCString { cstr in
                strncpy(ptr, cstr, maxPathLen - 1)
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(fd, sa, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bindResult == 0 else {
            logger.error("Failed to bind UNIX domain socket at \(path): \(errno)")
            close(fd)
            return
        }

        // Restrict permissions to owner-only 0600
        chmod(path, S_IRUSR | S_IWUSR)

        guard listen(fd, 16) == 0 else {
            logger.error("Failed to listen on UNIX domain socket: \(errno)")
            close(fd)
            return
        }

        // The fd is owned by the listen source's cancel handler below; stored
        // here only for accept() inside queue contexts.
        self.listeningSourceFd = fd

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptConnections()
        }
        // Sole owner of close/unlink for the listening fd. stop() only cancels;
        // the close happens here on `queue`, serialized with accept(), so the
        // descriptor can never be freed while the source may still fire.
        source.setCancelHandler {
            close(fd)
            unlink(path)
        }
        source.resume()
        self.listenSource = source
        logger.info("Control socket server listening on \(path)")
    }

    private func acceptConnections() {
        // The listening fd lives and dies on `queue`; reading it here is safe.
        var clientAddr = sockaddr_un()
        var clientLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let listenFd = listeningSourceFd

        while true {
            let clientFd = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    accept(listenFd, sa, &clientLen)
                }
            }

            if clientFd < 0 {
                break
            }

            handleClient(clientFd)
        }
    }

    // The fd is owned by the listen source's cancel handler; stored here only
    // for accept() inside queue contexts.
    private var listeningSourceFd: Int32 = -1

    private func handleClient(_ clientFd: Int32) {
        // Darwin: a write to a socket whose peer is gone raises SIGPIPE and
        // would kill the whole app. Opt this descriptor out.
        var nosigpipe: Int32 = 1
        _ = setsockopt(clientFd, SOL_SOCKET, SO_NOSIGPIPE, &nosigpipe, socklen_t(MemoryLayout.size(ofValue: nosigpipe)))

        let connection = ControlConnection(fd: clientFd)
        connection.start(provider: provider)
    }

    /// Cancels the listen source; the cancel handler (on `queue`) performs the
    /// close and unlink. Idempotent — safe to call from both termination paths.
    func stop() {
        listenSource?.cancel()
        listenSource = nil
    }
}
