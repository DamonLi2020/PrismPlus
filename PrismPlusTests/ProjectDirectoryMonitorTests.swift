import Foundation
import Testing

@testable import PrismPlus

@MainActor
struct ProjectDirectoryMonitorTests {
    @Test("A filesystem change is delivered without polling")
    func observesDirectoryChanges() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismPlusMonitor-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let monitor = ProjectDirectoryMonitor()
        var receivedChange = false
        monitor.start(watching: [root]) {
            receivedChange = true
        }

        try Data([1]).write(to: root.appendingPathComponent("new-resource.png"))
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while !receivedChange, clock.now < deadline {
            try await Task.sleep(for: .milliseconds(25))
        }
        monitor.stop()

        #expect(receivedChange)
    }
}
