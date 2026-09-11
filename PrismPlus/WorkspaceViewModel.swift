import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class WorkspaceViewModel: ObservableObject {
    enum BuildState: Equatable {
        case idle
        case waiting
        case compiling
        case succeeded
        case failed

        var label: String {
            switch self {
            case .idle: "Ready"
            case .waiting: "Waiting for complete syntax"
            case .compiling: "Compiling…"
            case .succeeded: "Preview current"
            case .failed: "Build failed"
            }
        }
    }

    @Published private(set) var source: String
    @Published private(set) var pdfData: Data?
    @Published private(set) var diagnostics: [CompilationDiagnostic] = []
    @Published private(set) var log = ""
    @Published private(set) var buildState: BuildState = .idle
    @Published private(set) var fileURL: URL?
    @Published private(set) var projectRootURL: URL?
    @Published private(set) var projectNodes: [ProjectNode] = []
    @Published private(set) var selectedExplorerDirectoryURL: URL?
    @Published private(set) var outlineItems: [LaTeXOutlineItem] = []
    @Published private(set) var isDirty = false
    @Published private(set) var hasOpenDocument = false

    private let compiler: any LaTeXCompiling
    private let projectFolderPicker: any ProjectFolderPicking
    private let workspaceResourcePicker: any WorkspaceResourcePicking
    private let projectDirectoryMonitor: any ProjectDirectoryMonitoring
    private var compilationTask: Task<Void, Never>?
    private var projectRefreshTask: Task<Void, Never>?

    init(
        compiler: any LaTeXCompiling = TectonicCompiler(),
        projectFolderPicker: any ProjectFolderPicking = SystemProjectFolderPicker(),
        workspaceResourcePicker: any WorkspaceResourcePicking = SystemWorkspaceResourcePicker(),
        projectDirectoryMonitor: any ProjectDirectoryMonitoring = ProjectDirectoryMonitor()
    ) {
        self.compiler = compiler
        self.projectFolderPicker = projectFolderPicker
        self.workspaceResourcePicker = workspaceResourcePicker
        self.projectDirectoryMonitor = projectDirectoryMonitor
        source = ""
    }

    var documentTitle: String {
        guard hasOpenDocument else { return "Prism Plus" }
        let name = fileURL?.lastPathComponent ?? "Untitled.tex"
        return isDirty ? "\(name) — Edited" : name
    }

    var shouldShowDocumentOutline: Bool {
        hasOpenDocument && !outlineItems.isEmpty
    }

    func updateSource(_ updatedSource: String, deferAutomaticCompilation: Bool = false) {
        guard hasOpenDocument else { return }
        guard updatedSource != source else { return }
        source = updatedSource
        outlineItems = LaTeXOutlineParser.parse(updatedSource)
        isDirty = true
        diagnostics = []
        if deferAutomaticCompilation {
            compilationTask?.cancel()
            buildState = .waiting
        } else {
            scheduleCompilation()
        }
    }

    func compileImmediately() {
        guard hasOpenDocument else { return }
        scheduleCompilation(delay: .zero, requiresReadySource: false)
    }

    func scheduleCompilation(
        delay: Duration = .milliseconds(900),
        requiresReadySource: Bool = true
    ) {
        guard hasOpenDocument else { return }
        compilationTask?.cancel()
        if requiresReadySource && !LaTeXSourceReadiness.isReady(source) {
            buildState = .waiting
            return
        }
        let sourceSnapshot = source
        let projectDirectorySnapshot = fileURL?.deletingLastPathComponent() ?? projectRootURL
        compilationTask = Task { [compiler] in
            do {
                try await Task.sleep(for: delay)
                try Task.checkCancellation()
                buildState = .compiling
                let result = try await compiler.compile(
                    source: sourceSnapshot,
                    projectDirectoryURL: projectDirectorySnapshot
                )
                try Task.checkCancellation()
                apply(result)
            } catch is CancellationError {
                return
            } catch {
                diagnostics = [
                    CompilationDiagnostic(
                        severity: .error,
                        message: error.localizedDescription
                    )
                ]
                log = error.localizedDescription
                buildState = .failed
            }
        }
    }

    func newDocument() {
        guard confirmDiscardIfNeeded() else { return }
        fileURL = nil
        source = LaTeXDocumentTemplate.standard
        outlineItems = LaTeXOutlineParser.parse(source)
        pdfData = nil
        diagnostics = []
        log = ""
        isDirty = false
        hasOpenDocument = true
        compileImmediately()
    }

    func openDocument() {
        guard confirmDiscardIfNeeded() else { return }
        guard let selection = workspaceResourcePicker.chooseResource() else { return }

        do {
            switch selection {
            case .latexFile(let selectedURL):
                try loadDocument(at: selectedURL)
                projectRootURL = selectedURL.deletingLastPathComponent()
                selectedExplorerDirectoryURL = projectRootURL
                try refreshProject()
            case .projectFolder(let selectedURL):
                try loadProject(at: selectedURL)
            }
        } catch {
            presentError(error)
        }
    }

    func openProject() {
        guard confirmDiscardIfNeeded() else { return }
        guard let selectedURL = projectFolderPicker.chooseFolder() else { return }

        do {
            try loadProject(at: selectedURL)
        } catch {
            presentError(error)
        }
    }

    func loadProject(at url: URL) throws {
        projectRootURL = url
        selectedExplorerDirectoryURL = url
        try refreshProject()
        closeDocumentForWelcomePage()
    }

    func selectExplorerRoot() {
        selectedExplorerDirectoryURL = projectRootURL
    }

    func selectExplorerDirectory(_ node: ProjectNode) {
        guard node.isDirectory, let projectRootURL else { return }
        let projectURLs = projectNodes.flatMap(\.flattened).map(\.url)
        guard projectURLs.contains(node.url), node.url != projectRootURL else { return }
        selectedExplorerDirectoryURL = node.url
    }

    func expandProjectDirectory(_ node: ProjectNode) {
        guard node.isDirectory else { return }
        let currentNode = projectNodes.flatMap(\.flattened).first(where: { $0.url == node.url })
        guard currentNode?.children == nil else { return }

        do {
            let children = try ProjectScanner.scan(rootURL: node.url)
            projectNodes = projectNodes.map {
                $0.replacingChildren(of: node.url, with: children)
            }
            restartProjectMonitoring()
        } catch {
            presentError(error)
        }
    }

    func selectProjectNode(_ node: ProjectNode) {
        guard node.isOpenable else { return }
        guard node.url != fileURL else { return }
        guard confirmDiscardIfNeeded() else { return }
        do {
            try loadDocument(at: node.url)
        } catch {
            presentError(error)
        }
    }

    @discardableResult
    func createProjectFile(named name: String, in directoryURL: URL) -> Bool {
        guard confirmDiscardIfNeeded(), let projectRootURL else { return false }
        do {
            let selectedURL = try ProjectResourceManager.create(
                named: name,
                kind: .latexFile,
                in: directoryURL,
                projectRoot: projectRootURL
            )
            try refreshProject()
            try loadDocument(at: selectedURL)
            return true
        } catch {
            presentError(error)
            return false
        }
    }

    @discardableResult
    func createProjectFolder(named name: String, in directoryURL: URL) -> Bool {
        guard let projectRootURL else { return false }
        do {
            let createdURL = try ProjectResourceManager.create(
                named: name,
                kind: .folder,
                in: directoryURL,
                projectRoot: projectRootURL
            )
            selectedExplorerDirectoryURL = createdURL
            try refreshProject()
            return true
        } catch {
            presentError(error)
            return false
        }
    }

    @discardableResult
    func renameProjectNode(_ node: ProjectNode, to name: String) -> Bool {
        guard let projectRootURL else { return false }
        if resourceContainsOpenDocument(node), !confirmDiscardIfNeeded() { return false }
        do {
            let renamedURL = try ProjectResourceManager.rename(
                node.url,
                to: name,
                as: ProjectResourceManager.kind(for: node),
                projectRoot: projectRootURL
            )
            if fileURL == node.url {
                fileURL = renamedURL
            }
            if selectedExplorerDirectoryURL == node.url {
                selectedExplorerDirectoryURL = renamedURL
            }
            try refreshProject()
            return true
        } catch {
            presentError(error)
            return false
        }
    }

    func moveProjectNodeToTrash(_ node: ProjectNode) {
        guard let projectRootURL else { return }
        if resourceContainsOpenDocument(node), !confirmDiscardIfNeeded() { return }

        let alert = NSAlert()
        alert.messageText = "Move “\(node.name)” to the Trash?"
        alert.informativeText = "You can restore it from the Trash later."
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try ProjectResourceManager.moveToTrash(node.url, projectRoot: projectRootURL)
            if resourceContainsOpenDocument(node) {
                closeDocumentForWelcomePage()
            }
            if selectedExplorerDirectoryURL == node.url {
                selectedExplorerDirectoryURL = node.url.deletingLastPathComponent()
            }
            try refreshProject()
        } catch {
            presentError(error)
        }
    }

    @discardableResult
    func moveDroppedResources(_ sourceURLs: [URL], into directoryURL: URL) -> Bool {
        guard let projectRootURL, !sourceURLs.isEmpty else { return false }
        do {
            _ = try ProjectResourceManager.moveImportedResources(
                sourceURLs,
                into: directoryURL,
                projectRoot: projectRootURL
            )
            try refreshProject()
            return true
        } catch {
            presentError(error)
            return false
        }
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func refreshProject() throws {
        guard let projectRootURL else {
            projectNodes = []
            return
        }

        let loadedDirectories = projectNodes.flatMap(\.flattened)
            .filter { $0.isDirectory && $0.children != nil }
            .map(\.url)
            .sorted { $0.pathComponents.count < $1.pathComponents.count }

        projectNodes = try ProjectScanner.scan(rootURL: projectRootURL)
        for directoryURL in loadedDirectories {
            var isDirectory: ObjCBool = false
            guard
                FileManager.default.fileExists(
                    atPath: directoryURL.path,
                    isDirectory: &isDirectory
                ), isDirectory.boolValue
            else { continue }
            let children = try ProjectScanner.scan(rootURL: directoryURL)
            projectNodes = projectNodes.map {
                $0.replacingChildren(of: directoryURL, with: children)
            }
        }
        restartProjectMonitoring()
    }

    func refreshProjectFromUserAction() {
        do {
            try refreshProject()
        } catch {
            presentError(error)
        }
    }

    var canDownloadPDF: Bool {
        pdfData != nil && buildState == .succeeded
    }

    var canSavePDFBesideSource: Bool {
        canDownloadPDF && fileURL != nil
    }

    func downloadPDF() {
        guard canDownloadPDF, let pdfData else { return }
        let panel = NSSavePanel()
        panel.title = "Download PDF"
        panel.nameFieldStringValue = PDFExportManager.suggestedFilename(for: fileURL)
        panel.directoryURL =
            FileManager.default.urls(
                for: .downloadsDirectory,
                in: .userDomainMask
            ).first
        panel.allowedContentTypes = [.pdf]
        panel.allowsOtherFileTypes = false
        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }

        do {
            try PDFExportManager.write(pdfData, to: destinationURL)
        } catch {
            presentError(error)
        }
    }

    func savePDFBesideSource() {
        guard canSavePDFBesideSource, let pdfData, let fileURL else { return }
        do {
            try PDFExportManager.write(
                pdfData,
                to: PDFExportManager.destinationBesideSource(for: fileURL)
            )
            try refreshProject()
        } catch {
            presentError(error)
        }
    }

    @discardableResult
    func saveDocument() -> Bool {
        guard hasOpenDocument else { return false }
        let destinationURL: URL
        if let fileURL {
            destinationURL = fileURL
        } else {
            let panel = NSSavePanel()
            panel.title = "Save LaTeX Document"
            panel.nameFieldStringValue = "main.tex"
            panel.allowedContentTypes = [Self.texContentType]
            panel.allowsOtherFileTypes = false
            guard panel.runModal() == .OK, let selectedURL = panel.url else { return false }
            destinationURL = selectedURL
        }

        do {
            try source.write(to: destinationURL, atomically: true, encoding: .utf8)
            fileURL = destinationURL
            isDirty = false
            if projectRootURL == nil {
                projectRootURL = destinationURL.deletingLastPathComponent()
                selectedExplorerDirectoryURL = projectRootURL
            }
            try refreshProject()
            return true
        } catch {
            presentError(error)
            return false
        }
    }

    private func apply(_ result: CompilationResult) {
        if let updatedPDF = result.pdfData, result.succeeded {
            pdfData = updatedPDF
        }
        diagnostics = result.diagnostics
        log = result.log
        buildState = result.succeeded ? .succeeded : .failed
    }

    private func loadDocument(at url: URL, compileAfterLoading: Bool = true) throws {
        guard url.pathExtension.lowercased() == "tex" else {
            throw WorkspaceError.unsupportedFileType
        }
        source = try String(contentsOf: url, encoding: .utf8)
        outlineItems = LaTeXOutlineParser.parse(source)
        fileURL = url
        isDirty = false
        hasOpenDocument = true
        if compileAfterLoading {
            compileImmediately()
        } else {
            pdfData = nil
            diagnostics = []
            log = ""
            buildState = .idle
        }
    }

    private func closeDocumentForWelcomePage() {
        compilationTask?.cancel()
        fileURL = nil
        source = ""
        outlineItems = []
        pdfData = nil
        diagnostics = []
        log = ""
        buildState = .idle
        isDirty = false
        hasOpenDocument = false
    }

    private func restartProjectMonitoring() {
        guard let projectRootURL else {
            projectDirectoryMonitor.stop()
            return
        }
        let loadedDirectories = Set(
            projectNodes.flatMap(\.flattened)
                .filter { $0.isDirectory && $0.children != nil }
                .map(\.url)
        )
        projectDirectoryMonitor.start(
            watching: loadedDirectories.union([projectRootURL])
        ) { [weak self] in
            self?.scheduleProjectRefreshFromFileSystem()
        }
    }

    private func scheduleProjectRefreshFromFileSystem() {
        projectRefreshTask?.cancel()
        projectRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? self?.refreshProject()
        }
    }

    private func resourceContainsOpenDocument(_ node: ProjectNode) -> Bool {
        guard let fileURL else { return false }
        if !node.isDirectory { return fileURL == node.url }
        let directoryPath = node.url.standardizedFileURL.path
        return fileURL.standardizedFileURL.path.hasPrefix("\(directoryPath)/")
    }

    private func confirmDiscardIfNeeded() -> Bool {
        guard isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = "Save changes to \(documentTitle)?"
        alert.informativeText = "Your changes will be lost if you don’t save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Don’t Save")

        switch alert.runModal() {
        case .alertFirstButtonReturn: return saveDocument()
        case .alertThirdButtonReturn: return true
        default: return false
        }
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }

    private static let texContentType = UTType(filenameExtension: "tex") ?? .plainText
}

private enum WorkspaceError: LocalizedError {
    case unsupportedFileType

    var errorDescription: String? {
        "Prism Plus can open only .tex documents."
    }
}
