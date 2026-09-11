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
        #expect(nodes[0].children == nil)
        #expect(nodes.flatMap(\.flattened).allSatisfy { !$0.url.path.contains("/build/") })
        #expect(nodes.first(where: { $0.name == "main.tex" })?.isOpenable == true)
        #expect(nodes.first(where: { $0.name == "figure.png" })?.isOpenable == false)
        #expect(nodes.first(where: { $0.name == "notes.md" })?.isOpenable == false)

        let chapterNodes = try ProjectScanner.scan(
            rootURL: root.appendingPathComponent("chapters", isDirectory: true)
        )
        #expect(chapterNodes.map(\.name) == ["one.tex"])
    }

    @Test("macOS application bundles remain expandable without eager recursive scanning")
    func lazilyScansApplicationBundles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismPlusApplications-\(UUID().uuidString)", isDirectory: true)
        let application = root.appendingPathComponent("Example.app", isDirectory: true)
        let internalResources = application.appendingPathComponent(
            "Contents/Resources/Nested",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(
            at: internalResources,
            withIntermediateDirectories: true
        )
        try "internal".write(
            to: internalResources.appendingPathComponent("not-a-project.tex"),
            atomically: true,
            encoding: .utf8
        )

        let nodes = try ProjectScanner.scan(rootURL: root)

        let applicationNode = try #require(nodes.first(where: { $0.name == "Example.app" }))
        #expect(applicationNode.isDirectory == true)
        #expect(applicationNode.children == nil)
        #expect(applicationNode.isOpenable == false)
        #expect(!applicationNode.flattened.contains { $0.name == "not-a-project.tex" })

        let applicationChildren = try ProjectScanner.scan(rootURL: application)
        let contentsNode = try #require(
            applicationChildren.first(where: { $0.name == "Contents" })
        )
        #expect(contentsNode.isDirectory == true)
        #expect(contentsNode.children == nil)
        #expect(!contentsNode.flattened.contains { $0.name == "not-a-project.tex" })
    }
}
