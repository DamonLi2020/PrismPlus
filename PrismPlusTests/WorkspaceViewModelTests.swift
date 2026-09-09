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
        #expect(model.source.contains(#"\begin{document}"#))
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

    @Test("Creating an empty project file opens it without compiling incomplete source")
    func opensNewEmptyFileWithoutCompiling() async throws {
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
        #expect(model.buildState == .idle)
        #expect(await compiler.compilationCount == 0)
    }
}

private actor RecordingCompiler: LaTeXCompiling {
    private(set) var compilationCount = 0

    func compile(source: String) async throws -> CompilationResult {
        compilationCount += 1
        return CompilationResult(succeeded: true, pdfData: nil, diagnostics: [], log: "")
    }
}
