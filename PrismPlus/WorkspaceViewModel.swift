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
    @Published private(set) var isDirty = false
    @Published private(set) var hasOpenDocument = false

    private let compiler: any LaTeXCompiling
    private var compilationTask: Task<Void, Never>?

    init(compiler: any LaTeXCompiling = TectonicCompiler()) {
        self.compiler = compiler
        source = ""
    }

    var documentTitle: String {
        guard hasOpenDocument else { return "Prism Plus" }
        let name = fileURL?.lastPathComponent ?? "Untitled.tex"
        return isDirty ? "\(name) — Edited" : name
    }

    func updateSource(_ updatedSource: String, deferAutomaticCompilation: Bool = false) {
        guard hasOpenDocument else { return }
        guard updatedSource != source else { return }
        source = updatedSource
        isDirty = true
        if deferAutomaticCompilation {
            compilationTask?.cancel()
            diagnostics = []
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
        let projectDirectorySnapshot = projectRootURL
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
        source = Self.starterDocument
        pdfData = nil
        diagnostics = []
        log = ""
        isDirty = false
        hasOpenDocument = true
        compileImmediately()
    }

    func openDocument() {
        guard confirmDiscardIfNeeded() else { return }

        let panel = NSOpenPanel()
        panel.title = "Open LaTeX Document"
        panel.allowedContentTypes = [Self.texContentType]
        panel.allowsOtherFileTypes = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }

        do {
            try loadDocument(at: selectedURL)
            projectRootURL = selectedURL.deletingLastPathComponent()
            selectedExplorerDirectoryURL = projectRootURL
            try refreshProject()
        } catch {
            presentError(error)
        }
    }

    func openProject() {
        guard confirmDiscardIfNeeded() else { return }
        let panel = NSOpenPanel()
        panel.title = "Open LaTeX Project"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }

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
            try loadDocument(at: selectedURL, compileAfterLoading: false)
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

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func refreshProject() throws {
        guard let projectRootURL else {
            projectNodes = []
            return
        }
        projectNodes = try ProjectScanner.scan(rootURL: projectRootURL)
    }

    func refreshProjectFromUserAction() {
        do {
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
        pdfData = nil
        diagnostics = []
        log = ""
        buildState = .idle
        isDirty = false
        hasOpenDocument = false
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

    private static let starterDocument = #"""
        \documentclass[11pt]{article}
        \usepackage{amsmath}

        \title{Prism Plus}
        \author{Damon Li}
        \date{\today}

        \begin{document}
        \maketitle

        \section{A local LaTeX workspace}
        Edit this source and the PDF preview will update automatically.

        \[
          e^{i\pi} + 1 = 0
        \]
        \end{document}
        """#

    private static let texContentType = UTType(filenameExtension: "tex") ?? .plainText
}

private enum WorkspaceError: LocalizedError {
    case unsupportedFileType

    var errorDescription: String? {
        "Prism Plus can open only .tex documents."
    }
}
