import Foundation
import Testing

@testable import PrismPlus

struct ProjectResourceManagerTests {
    @Test("A LaTeX file is created in the selected folder with a tex suffix")
    func createsLatexFileInSelectedFolder() throws {
        let fixture = try ProjectFixture()
        defer { fixture.remove() }
        let chapters = try fixture.createDirectory(named: "chapters")

        let createdURL = try ProjectResourceManager.create(
            named: "introduction",
            kind: .latexFile,
            in: chapters,
            projectRoot: fixture.root
        )

        #expect(createdURL == chapters.appendingPathComponent("introduction.tex"))
        #expect(FileManager.default.fileExists(atPath: createdURL.path))
        #expect(try String(contentsOf: createdURL, encoding: .utf8) == "")
    }

    @Test("An existing tex suffix is not duplicated")
    func preservesExistingLatexSuffix() throws {
        let fixture = try ProjectFixture()
        defer { fixture.remove() }

        let createdURL = try ProjectResourceManager.create(
            named: "main.tex",
            kind: .latexFile,
            in: fixture.root,
            projectRoot: fixture.root
        )

        #expect(createdURL.lastPathComponent == "main.tex")
    }

    @Test("A folder is created in the selected folder")
    func createsFolderInSelectedFolder() throws {
        let fixture = try ProjectFixture()
        defer { fixture.remove() }
        let sections = try fixture.createDirectory(named: "sections")

        let createdURL = try ProjectResourceManager.create(
            named: "appendices",
            kind: .folder,
            in: sections,
            projectRoot: fixture.root
        )

        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: createdURL.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
    }

    @Test("Creation rejects traversal and existing resources")
    func rejectsUnsafeOrDuplicateNames() throws {
        let fixture = try ProjectFixture()
        defer { fixture.remove() }
        _ = try ProjectResourceManager.create(
            named: "main",
            kind: .latexFile,
            in: fixture.root,
            projectRoot: fixture.root
        )

        #expect(throws: ProjectResourceError.self) {
            try ProjectResourceManager.create(
                named: "../escape",
                kind: .latexFile,
                in: fixture.root,
                projectRoot: fixture.root
            )
        }
        #expect(throws: ProjectResourceError.self) {
            try ProjectResourceManager.create(
                named: "main.tex",
                kind: .latexFile,
                in: fixture.root,
                projectRoot: fixture.root
            )
        }
    }

    @Test("A resource can be renamed without leaving the project")
    func renamesResource() throws {
        let fixture = try ProjectFixture()
        defer { fixture.remove() }
        let originalURL = try ProjectResourceManager.create(
            named: "draft",
            kind: .latexFile,
            in: fixture.root,
            projectRoot: fixture.root
        )

        let renamedURL = try ProjectResourceManager.rename(
            originalURL,
            to: "chapter-one",
            as: .latexFile,
            projectRoot: fixture.root
        )

        #expect(renamedURL.lastPathComponent == "chapter-one.tex")
        #expect(!FileManager.default.fileExists(atPath: originalURL.path))
        #expect(FileManager.default.fileExists(atPath: renamedURL.path))
    }
}

private struct ProjectFixture {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismPlusResources-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func createDirectory(named name: String) throws -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
