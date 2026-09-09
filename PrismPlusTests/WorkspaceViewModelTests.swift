import Foundation
import Testing

@testable import PrismPlus

@MainActor
struct WorkspaceViewModelTests {
    @Test("A new workspace starts on the welcome page without compiling")
    func startsOnWelcomePage() async throws {
        let compiler = RecordingCompiler()
        let model = WorkspaceViewModel(compiler: compiler)

        #expect(!model.hasOpenDocument)
        #expect(model.source.isEmpty)
        #expect(model.documentTitle == "Prism Plus")

        model.compileImmediately()
        try await Task.sleep(for: .milliseconds(100))
        let compilationCount = await compiler.compilationCount
        #expect(compilationCount == 0)
    }

    @Test("Creating a document leaves the welcome page and supplies a LaTeX template")
    func createsDocumentFromWelcomePage() {
        let model = WorkspaceViewModel(compiler: RecordingCompiler())

        model.newDocument()

        #expect(model.hasOpenDocument)
        #expect(model.source.contains(#"\title{Your Document Title}"#))
        #expect(model.source.contains(#"\author{Damon Li}"#))
        #expect(model.source.contains(#"\begin{document}"#))
        #expect(model.source.contains("Start writing here."))
        #expect(model.documentTitle == "Untitled.tex")
    }

    @Test("Incomplete completion input waits without invoking the compiler")
    func defersAutomaticCompilationForCompletionInput() async throws {
        let compiler = RecordingCompiler()
        let model = WorkspaceViewModel(compiler: compiler)

        model.newDocument()

        model.updateSource(#"\s"#, deferAutomaticCompilation: true)

        #expect(model.buildState == .waiting)
        #expect(model.diagnostics.isEmpty)
        try await Task.sleep(for: .milliseconds(1_000))
        let compilationCount = await compiler.compilationCount
        #expect(compilationCount == 0)
    }

    @Test("The most recently selected folder becomes the creation destination")
    func tracksSelectedExplorerFolder() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismPlusSelection-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("first"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("second"),
            withIntermediateDirectories: true
        )
        let model = WorkspaceViewModel(compiler: RecordingCompiler())
        try model.loadProject(at: root)
        let folders = model.projectNodes.filter(\.isDirectory)

        model.selectExplorerDirectory(folders[0])
        model.selectExplorerDirectory(folders[1])

        #expect(model.selectedExplorerDirectoryURL == folders[1].url)
    }

    @Test("Creating a project file opens and compiles its starter document")
    func opensAndCompilesNewFileTemplate() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismPlusNewFile-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let compiler = RecordingCompiler()
        let model = WorkspaceViewModel(compiler: compiler)
        try model.loadProject(at: root)

        let created = model.createProjectFile(named: "chapter", in: root)
        try await Task.sleep(for: .milliseconds(100))

        #expect(created)
        #expect(model.fileURL == root.appendingPathComponent("chapter.tex"))
        #expect(model.source.contains(#"\documentclass[11pt]{article}"#))
        #expect(model.source.contains(#"\title{Your Document Title}"#))
        #expect(model.source.contains("Start writing here."))
        #expect(model.buildState == .succeeded)
        #expect(await compiler.compilationCount == 1)
    }

    @Test("Saving a compiled PDF beside its source refreshes the project")
    func savesPDFBesideSource() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismPlusAdjacentPDF-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let expectedPDF = Data("compiled-pdf".utf8)
        let compiler = RecordingCompiler(pdfData: expectedPDF)
        let model = WorkspaceViewModel(compiler: compiler)
        try model.loadProject(at: root)

        #expect(model.createProjectFile(named: "paper", in: root))
        try await Task.sleep(for: .milliseconds(100))
        model.savePDFBesideSource()

        let destination = root.appendingPathComponent("paper.pdf")
        #expect(try Data(contentsOf: destination) == expectedPDF)
        #expect(model.projectNodes.contains { $0.name == "paper.pdf" && !$0.isOpenable })
    }
}

private actor RecordingCompiler: LaTeXCompiling {
    private(set) var compilationCount = 0
    private let pdfData: Data?

    init(pdfData: Data? = nil) {
        self.pdfData = pdfData
    }

    func compile(source: String) async throws -> CompilationResult {
        compilationCount += 1
        return CompilationResult(succeeded: true, pdfData: pdfData, diagnostics: [], log: "")
    }
}
