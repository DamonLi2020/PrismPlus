import Foundation
import Testing

@testable import PrismPlus

struct ProjectScannerTests {
    @Test("Project scanner builds a sorted tree and hides generated files")
    func scansProjectFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismPlusProject-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("chapters"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("build"),
            withIntermediateDirectories: true
        )
        try "main".write(
            to: root.appendingPathComponent("main.tex"),
            atomically: true,
            encoding: .utf8
        )
        try "chapter".write(
            to: root.appendingPathComponent("chapters/one.tex"),
            atomically: true,
            encoding: .utf8
        )
        try "generated".write(
            to: root.appendingPathComponent("build/main.log"),
            atomically: true,
            encoding: .utf8
        )
        try "hidden".write(
            to: root.appendingPathComponent(".secret.tex"),
            atomically: true,
            encoding: .utf8
        )

        let nodes = try ProjectScanner.scan(rootURL: root)

        #expect(nodes.map(\.name) == ["chapters", "main.tex"])
        #expect(nodes[0].children?.map(\.name) == ["one.tex"])
        #expect(nodes.flatMap(\.flattened).allSatisfy { !$0.url.path.contains("/build/") })
    }
}
