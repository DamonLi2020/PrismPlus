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
        #expect(!model.shouldShowDocumentOutline)
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
        #expect(model.shouldShowDocumentOutline)
        #expect(model.source.contains(#"\title{Your Document Title}"#))
        #expect(model.source.contains(#"\author{Damon Li}"#))
        #expect(model.source.contains(#"\begin{document}"#))
        #expect(model.source.contains("Start writing here."))
        #expect(model.documentTitle == "Untitled.tex")
    }

    @Test("The document outline stays hidden until an open document has headings")
    func showsOutlineOnlyForOutlineableDocuments() {
        let model = WorkspaceViewModel(compiler: RecordingCompiler())

        model.newDocument()
        model.updateSource(
            #"\documentclass{article}\begin{document}\end{document}"#,
            deferAutomaticCompilation: true
        )

        #expect(model.hasOpenDocument)
        #expect(!model.shouldShowDocumentOutline)

        model.updateSource(
            #"""
            \documentclass{article}
            \begin{document}
            \section{Introduction}
            \end{document}
            """#,
            deferAutomaticCompilation: true
        )

        #expect(model.shouldShowDocumentOutline)
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

    @Test("Expanding a folder loads only its immediate children")
    func lazilyLoadsExplorerChildren() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismPlusLazy-\(UUID().uuidString)", isDirectory: true)
        let folder = root.appendingPathComponent("Example.app", isDirectory: true)
        let nested = folder.appendingPathComponent("Contents/Resources", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "source".write(
            to: nested.appendingPathComponent("internal.tex"),
            atomically: true,
            encoding: .utf8
        )

        let model = WorkspaceViewModel(compiler: RecordingCompiler())
        try model.loadProject(at: root)
        let folderNode = try #require(
            model.projectNodes.first(where: { $0.name == "Example.app" })
        )
        #expect(folderNode.children == nil)

        model.expandProjectDirectory(folderNode)

        let expandedFolder = try #require(
            model.projectNodes.first(where: { $0.url == folderNode.url })
        )
        #expect(expandedFolder.children?.map(\.name) == ["Contents"])
        #expect(expandedFolder.children?.first?.children == nil)
    }

    @Test("Expanded folders are enrolled in automatic project monitoring")
    func monitorsExpandedExplorerFolders() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismPlusNestedSync-\(UUID().uuidString)", isDirectory: true)
        let child = root.appendingPathComponent("assets", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        let monitor = RecordingProjectDirectoryMonitor()
        let model = WorkspaceViewModel(
            compiler: RecordingCompiler(),
            projectDirectoryMonitor: monitor
        )
        try model.loadProject(at: root)
        let childNode = try #require(model.projectNodes.first { $0.name == "assets" })

        model.expandProjectDirectory(childNode)

        #expect(
            Set(monitor.watchedDirectoryURLs.map { $0.resolvingSymlinksInPath().path })
                == Set([root, child].map { $0.resolvingSymlinksInPath().path })
        )
    }

    @Test("Opening a project uses the selected folder from the folder picker")
    func opensProjectFromFolderPicker() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismPlusPicker-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let model = WorkspaceViewModel(
            compiler: RecordingCompiler(),
            projectFolderPicker: StubProjectFolderPicker(selectedURL: root)
        )

        model.openProject()

        #expect(model.projectRootURL == root)
        #expect(!model.hasOpenDocument)
    }

    @Test("Command-O can open a project folder from the unified picker")
    func opensProjectFolderFromUnifiedPicker() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "PrismPlusUnifiedFolder-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let model = WorkspaceViewModel(
            compiler: RecordingCompiler(),
            workspaceResourcePicker: StubWorkspaceResourcePicker(selection: .projectFolder(root))
        )

        model.openDocument()

        #expect(model.projectRootURL == root)
        #expect(!model.hasOpenDocument)
    }

    @Test("Command-O still opens a selected LaTeX document")
    func opensDocumentFromUnifiedPicker() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismPlusUnifiedFile-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let documentURL = root.appendingPathComponent("paper.tex")
        try LaTeXDocumentTemplate.standard.write(
            to: documentURL,
            atomically: true,
            encoding: .utf8
        )
        let model = WorkspaceViewModel(
            compiler: RecordingCompiler(),
            workspaceResourcePicker: StubWorkspaceResourcePicker(selection: .latexFile(documentURL))
        )

        model.openDocument()

        #expect(model.fileURL == documentURL)
        #expect(model.hasOpenDocument)
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

    @Test("External project changes automatically refresh the Explorer")
    func automaticallyRefreshesExternalChanges() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismPlusSync-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let monitor = RecordingProjectDirectoryMonitor()
        let model = WorkspaceViewModel(
            compiler: RecordingCompiler(),
            projectDirectoryMonitor: monitor
        )
        try model.loadProject(at: root)
        #expect(monitor.watchedDirectoryURLs == [root])

        let addedURL = root.appendingPathComponent("added.png")
        try Data([1, 2, 3]).write(to: addedURL)
        monitor.sendChange()
        try await waitUntil {
            model.projectNodes.contains { $0.name == addedURL.lastPathComponent }
        }

        #expect(model.projectNodes.contains { $0.name == addedURL.lastPathComponent })

        try FileManager.default.removeItem(at: addedURL)
        monitor.sendChange()
        try await waitUntil {
            !model.projectNodes.contains { $0.name == addedURL.lastPathComponent }
        }

        #expect(!model.projectNodes.contains { $0.name == addedURL.lastPathComponent })
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition(), clock.now < deadline {
            try await Task.sleep(for: .milliseconds(25))
        }
    }
}

private struct StubProjectFolderPicker: ProjectFolderPicking {
    let selectedURL: URL?

    func chooseFolder() -> URL? {
        selectedURL
    }
}

private struct StubWorkspaceResourcePicker: WorkspaceResourcePicking {
    let selection: WorkspaceResourceSelection?

    func chooseResource() -> WorkspaceResourceSelection? {
        selection
    }
}

@MainActor
private final class RecordingProjectDirectoryMonitor: ProjectDirectoryMonitoring {
    private(set) var watchedDirectoryURLs: Set<URL> = []
    private var onChange: (@MainActor () -> Void)?

    func start(
        watching directoryURLs: Set<URL>,
        onChange: @escaping @MainActor () -> Void
    ) {
        watchedDirectoryURLs = directoryURLs
        self.onChange = onChange
    }

    func stop() {
        watchedDirectoryURLs = []
        onChange = nil
    }

    func sendChange() {
        onChange?()
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
