import Foundation
import Testing

@testable import PrismPlus

struct ProjectScannerTests {
    @Test("Project scanner shows project resources while marking only TeX files openable")
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
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("empty"),
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
        try "notes".write(
            to: root.appendingPathComponent("notes.md"),
            atomically: true,
            encoding: .utf8
        )
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: root.appendingPathComponent("figure.png"))
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

        #expect(nodes.map(\.name) == ["chapters", "empty", "figure.png", "main.tex", "notes.md"])
        #expect(nodes[0].children?.map(\.name) == ["one.tex"])
        #expect(nodes.flatMap(\.flattened).allSatisfy { !$0.url.path.contains("/build/") })
        #expect(nodes.first(where: { $0.name == "main.tex" })?.isOpenable == true)
        #expect(nodes.first(where: { $0.name == "figure.png" })?.isOpenable == false)
        #expect(nodes.first(where: { $0.name == "notes.md" })?.isOpenable == false)
    }
}
