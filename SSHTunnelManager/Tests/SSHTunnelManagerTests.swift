import XCTest
@testable import SSHTunnelManager

/// Ephemeral UserDefaults suite so tests never touch the user's real prefs.
enum TestPreferences {
    static func install() {
        let suite = UserDefaults(suiteName: "SSHTunnelManagerTests")
        suite?.removePersistentDomain(forName: "SSHTunnelManagerTests")
        AppPreferences.defaults = suite ?? .standard
    }

    static func reset() {
        AppPreferences.defaults = .standard
    }
}

final class PortAllocatorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        TestPreferences.install()
    }

    override func tearDown() {
        TestPreferences.reset()
        super.tearDown()
    }

    func testMirrorModeReturnsServicePortAndPreservesFrontier() {
        let result = PortAllocator.allocate(
            servicePort: 8080,
            findNextHighPort: false,
            frontier: 4096,
            occupiedLocalPorts: [4096, 4097]
        )
        XCTAssertEqual(result?.localPort, 8080)
        XCTAssertEqual(result?.candidateFrontier, 4096)
    }

    func testFrontierModeAllocatesFrontierPlusOne() {
        let result = PortAllocator.allocate(
            servicePort: 4096,
            findNextHighPort: true,
            frontier: 4096,
            occupiedLocalPorts: []
        )
        XCTAssertEqual(result?.localPort, 4097)
        XCTAssertEqual(result?.candidateFrontier, 4097)
    }

    func testSkipsOccupiedPorts() {
        let result = PortAllocator.allocate(
            servicePort: 4096,
            findNextHighPort: true,
            frontier: 4096,
            occupiedLocalPorts: [4097, 4098]
        )
        XCTAssertEqual(result?.localPort, 4099)
    }

    func testWraparoundNeverReturnsOccupiedFrontier() {
        // Regression: the fallback scan used to stop at `fallback < frontier`,
        // returning an occupied frontier when every port above it was taken.
        let occupied: Set<Int> = [1024, 1025, 1026, 65535]
        let result = PortAllocator.allocate(
            servicePort: 4096,
            findNextHighPort: true,
            frontier: 1026,
            occupiedLocalPorts: occupied
        )
        XCTAssertNotNil(result)
        XCTAssertFalse(occupied.contains(result!.localPort), "allocator returned an occupied port: \(result!.localPort)")
        XCTAssertEqual(result?.localPort, 1027)
    }

    func testWraparoundAtFullTopRange() {
        // frontier 65535 with only 1024 occupied — wrap lands on the first free port.
        let result = PortAllocator.allocate(
            servicePort: 4096,
            findNextHighPort: true,
            frontier: 65535,
            occupiedLocalPorts: [1024]
        )
        XCTAssertEqual(result?.localPort, 1025)
        // Wraparound must not regress the frontier.
        XCTAssertEqual(result?.candidateFrontier, 65535)
    }

    func testExhaustionReturnsNil() {
        // Regression: total exhaustion used to return the frontier unconditionally.
        var occupied: Set<Int> = []
        for port in AppPreferences.minPort...AppPreferences.maxPort {
            occupied.insert(port)
        }
        let result = PortAllocator.allocate(
            servicePort: 4096,
            findNextHighPort: true,
            frontier: 4096,
            occupiedLocalPorts: occupied
        )
        XCTAssertNil(result)
    }
}

final class RemoteForwardFrontierTests: XCTestCase {
    override func setUp() {
        super.setUp()
        TestPreferences.install()
    }

    override func tearDown() {
        TestPreferences.reset()
        super.tearDown()
    }

    @MainActor
    func testRemoteForwardLocalPortDoesNotAdvanceFrontierOrOccupyLocalPorts() {
        // Regression: saveChanges()/addTunnel() flat-mapped every mapping's
        // localPort, so a -R forward's dial-back target (30000) advanced
        // maxAllocatedPort and was treated as locally occupied.
        var remoteForward = PortMapping(localPort: 30000, remotePort: 8080)
        remoteForward.forward = .remote
        let tunnel = Tunnel(name: "r", host: "h", portMappings: [remoteForward])

        XCTAssertEqual(tunnel.locallyBoundPorts, [], "-R forward must not count as locally bound")

        AppPreferences.maxAllocatedPort = 4096
        for port in tunnel.locallyBoundPorts {
            AppPreferences.recordAllocatedPort(port)
        }
        XCTAssertEqual(AppPreferences.maxAllocatedPort, 4096, "frontier advanced from a remote forward's localPort")

        let next = PortAllocator.allocate(
            servicePort: 4096,
            findNextHighPort: true,
            frontier: AppPreferences.maxAllocatedPort,
            occupiedLocalPorts: Set(tunnel.locallyBoundPorts)
        )
        XCTAssertEqual(next?.localPort, 4097, "next allocation seeded by the -R target port")
    }
}

final class PreferencesDraftTests: XCTestCase {
    override func setUp() {
        super.setUp()
        TestPreferences.install()
    }

    override func tearDown() {
        TestPreferences.reset()
        super.tearDown()
    }

    @MainActor
    func testStartsLockedAndMirrorsEdits() {
        let draft = PreferencesDraft()
        XCTAssertTrue(draft.isLocked)

        draft.updateDefaultServicePort(5000)
        XCTAssertEqual(draft.defaultServicePort, 5000)
        XCTAssertEqual(draft.maxAllocatedPort, 5000)

        draft.updateMaxAllocatedPort(6000)
        XCTAssertEqual(draft.defaultServicePort, 6000)
        XCTAssertEqual(draft.maxAllocatedPort, 6000)
    }

    @MainActor
    func testUnlockedEditsVaryFreelyAndRelockReconcilesToMax() {
        let draft = PreferencesDraft()
        draft.updateDefaultServicePort(5000)
        draft.toggleLock()
        XCTAssertFalse(draft.isLocked)

        draft.updateDefaultServicePort(7000)
        XCTAssertEqual(draft.defaultServicePort, 7000)
        XCTAssertEqual(draft.maxAllocatedPort, 5000)

        draft.toggleLock()
        XCTAssertTrue(draft.isLocked)
        XCTAssertEqual(draft.defaultServicePort, 7000)
        XCTAssertEqual(draft.maxAllocatedPort, 7000)
    }

    @MainActor
    func testCommitPersistsAndClampsOutOfRangeValues() {
        let draft = PreferencesDraft()
        draft.toggleLock() // unlock so the two ports can diverge
        draft.updateDefaultServicePort(70000) // out of range
        draft.updateMaxAllocatedPort(5000)
        draft.commit()

        // 70000 clamps to maxPort on persist.
        XCTAssertEqual(AppPreferences.defaultServicePort, AppPreferences.maxPort)
        XCTAssertEqual(AppPreferences.maxAllocatedPort, 5000)
        XCTAssertTrue(AppPreferences.hasCompletedFirstLaunch)
    }
}

final class LineFramerTests: XCTestCase {
    func testFragmentedChunksProduceNoLinesUntilNewline() {
        var framer = LineFramer()
        let first = (try? framer.append(Data("{\"id\":\"1\",\"met".utf8))) ?? []
        XCTAssertTrue(first.isEmpty)

        let second = (try? framer.append(Data("hod\":\"describe\"}\n{\"id\":\"2\"}\r\n".utf8))) ?? []
        XCTAssertEqual(second.count, 2)
        XCTAssertEqual(second[0], "{\"id\":\"1\",\"method\":\"describe\"}")
        XCTAssertEqual(second[1], "{\"id\":\"2\"}")
    }

    func testRejectsOverlongUnterminatedTail() {
        var framer = LineFramer()
        XCTAssertThrowsError(try framer.append(Data(repeating: 0x41, count: LineFramer.maxFrameSize + 1)))
    }

    func testNewlineEmbeddedPayloadCannotBypassLimit() {
        // Regression: the old guard skipped the size check whenever the buffer
        // contained any newline, so <64 KiB>\n<huge tail> grew without bound.
        var framer = LineFramer()
        let payload = Data(repeating: 0x41, count: LineFramer.maxFrameSize)
            + Data([0x0A])
            + Data(repeating: 0x42, count: LineFramer.maxFrameSize + 1)
        XCTAssertThrowsError(try framer.append(payload), "newline-embedded oversized segment must throw")
    }

    func testIndividualOversizedLineThrows() {
        var framer = LineFramer()
        let payload = Data(repeating: 0x41, count: LineFramer.maxFrameSize + 1) + Data([0x0A])
        XCTAssertThrowsError(try framer.append(payload))
    }

    func testExactlyMaxFrameSizeLineIsAccepted() {
        var framer = LineFramer()
        let lines = (try? framer.append(Data(repeating: 0x41, count: LineFramer.maxFrameSize) + Data([0x0A]))) ?? []
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].count, LineFramer.maxFrameSize)
    }
}

final class ControlProtocolTests: XCTestCase {
    private final class MockProvider: TunnelStateProvider, @unchecked Sendable {
        func systemStatusSnapshot() -> SystemStatusSnapshot {
            SystemStatusSnapshot(
                version: "1.10.0",
                totalTunnels: 2,
                activeTunnels: 1,
                defaultServicePort: 4096,
                maxAllocatedPort: 4098,
                findNextHighPort: true
            )
        }

        func tunnelSnapshots() -> [TunnelSnapshot] {
            [
                TunnelSnapshot(
                    id: "mock-1",
                    name: "vps0",
                    host: "root@vps0.stenographer.cloud",
                    port: 22,
                    status: "connected",
                    portMappings: [
                        PortMappingSnapshot(mapping: PortMapping(localPort: 4096, remotePort: 4096))
                    ],
                    lastError: nil,
                    pid: 1234
                )
            ]
        }
    }

    @MainActor
    func testDescribeReturnsMethodList() {
        let out = ControlProtocol.handleLine("{\"id\":\"1\",\"method\":\"describe\"}\n", provider: MockProvider())
        let obj = (try? JSONSerialization.jsonObject(with: Data(out.utf8)) as? [String: Any]) ?? [:]
        XCTAssertEqual(obj["id"] as? String, "1")
        let methods = (obj["result"] as? [String: Any])?["methods"] as? [String]
        XCTAssertEqual(methods, ["describe", "get_status", "list_tunnels"])
    }

    @MainActor
    func testGetStatusReturnsFrontierState() {
        let out = ControlProtocol.handleLine("{\"id\":\"2\",\"method\":\"get_status\"}\n", provider: MockProvider())
        let obj = (try? JSONSerialization.jsonObject(with: Data(out.utf8)) as? [String: Any]) ?? [:]
        let result = obj["result"] as? [String: Any]
        XCTAssertEqual(result?["defaultServicePort"] as? Int, 4096)
        XCTAssertEqual(result?["maxAllocatedPort"] as? Int, 4098)
        XCTAssertEqual(result?["findNextHighPort"] as? Bool, true)
    }

    @MainActor
    func testListTunnelsReturnsSnapshots() {
        let out = ControlProtocol.handleLine("{\"id\":\"3\",\"method\":\"list_tunnels\"}\n", provider: MockProvider())
        let obj = (try? JSONSerialization.jsonObject(with: Data(out.utf8)) as? [String: Any]) ?? [:]
        let tunnels = (obj["result"] as? [String: Any])?["tunnels"] as? [[String: Any]]
        XCTAssertEqual(tunnels?.count, 1)
        XCTAssertEqual(tunnels?.first?["name"] as? String, "vps0")
        XCTAssertEqual(tunnels?.first?["status"] as? String, "connected")
    }

    @MainActor
    func testUnknownMethodReturnsMethodNotFound() {
        let out = ControlProtocol.handleLine("{\"id\":\"4\",\"method\":\"nope\"}\n", provider: MockProvider())
        let obj = (try? JSONSerialization.jsonObject(with: Data(out.utf8)) as? [String: Any]) ?? [:]
        XCTAssertEqual((obj["error"] as? [String: Any])?["code"] as? Int, -32601)
    }

    @MainActor
    func testBrokenJSONReturnsInvalidRequest() {
        let out = ControlProtocol.handleLine("broken json\n", provider: MockProvider())
        let obj = (try? JSONSerialization.jsonObject(with: Data(out.utf8)) as? [String: Any]) ?? [:]
        XCTAssertEqual((obj["error"] as? [String: Any])?["code"] as? Int, -32600)
    }

    @MainActor
    func testErrorResponsesAreAlwaysWellFormedJSON() {
        // Client-controlled strings containing JSON metacharacters must never
        // produce a malformed frame from the encoder path. Built via
        // JSONSerialization so the request itself is guaranteed well-formed
        // regardless of Swift string-escaping pitfalls.
        let request = try! JSONSerialization.data(withJSONObject: [
            "id": "injected\"},\"x\":1",
            "method": "no\"pe",
        ])
        let line = String(decoding: request, as: UTF8.self) + "\n"
        let out = ControlProtocol.handleLine(line, provider: MockProvider())
        let obj = (try? JSONSerialization.jsonObject(with: Data(out.utf8)) as? [String: Any]) ?? [:]
        XCTAssertEqual(obj["id"] as? String, "injected\"},\"x\":1")
        XCTAssertNotNil(obj["error"])
    }
}
