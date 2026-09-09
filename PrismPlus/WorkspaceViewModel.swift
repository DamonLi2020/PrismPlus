import AppKit
import Foundation

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
    @Published private(set) var isDirty = false

    private let compiler: any LaTeXCompiling
    private var compilationTask: Task<Void, Never>?

    init(compiler: any LaTeXCompiling = TectonicCompiler()) {
        self.compiler = compiler
        source = Self.starterDocument
    }

    var documentTitle: String {
        let name = fileURL?.lastPathComponent ?? "Untitled.tex"
        return isDirty ? "\(name) — Edited" : name
    }

    func updateSource(_ updatedSource: String) {
        guard updatedSource != source else { return }
        source = updatedSource
        isDirty = true
        scheduleCompilation()
    }

    func compileImmediately() {
        scheduleCompilation(delay: .zero, requiresReadySource: false)
    }

    func scheduleCompilation(
        delay: Duration = .milliseconds(900),
        requiresReadySource: Bool = true
    ) {
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
        compileImmediately()
    }

    func openDocument() {
        guard confirmDiscardIfNeeded() else { return }

        let panel = NSOpenPanel()
        panel.title = "Open LaTeX Document"
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }

        do {
            try loadDocument(at: selectedURL)
            projectRootURL = selectedURL.deletingLastPathComponent()
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
            projectRootURL = selectedURL
            try refreshProject()
            if let main = projectNodes.flatMap(\.flattened).first(where: { $0.name == "main.tex" })
                ?? projectNodes.flatMap(\.flattened).first(where: {
                    $0.url.pathExtension.lowercased() == "tex"
                })
            {
                try loadDocument(at: main.url)
            }
        } catch {
            presentError(error)
        }
    }

    func selectProjectNode(_ node: ProjectNode) {
        guard !node.isDirectory, node.url.pathExtension.lowercased() == "tex" else { return }
        guard node.url != fileURL else { return }
        guard confirmDiscardIfNeeded() else { return }
        do {
            try loadDocument(at: node.url)
        } catch {
            presentError(error)
        }
    }

    func createProjectFile() {
        let panel = NSSavePanel()
        panel.title = "Create LaTeX File"
        panel.nameFieldStringValue = "chapter.tex"
        panel.allowedContentTypes = [.plainText]
        panel.directoryURL = projectRootURL
        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }

        do {
            let initialSource = "% \(selectedURL.deletingPathExtension().lastPathComponent)\n"
            try initialSource.write(to: selectedURL, atomically: true, encoding: .utf8)
            try refreshProject()
            try loadDocument(at: selectedURL)
        } catch {
            presentError(error)
        }
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
        let destinationURL: URL
        if let fileURL {
            destinationURL = fileURL
        } else {
            let panel = NSSavePanel()
            panel.title = "Save LaTeX Document"
            panel.nameFieldStringValue = "main.tex"
            panel.allowedContentTypes = [.plainText]
            guard panel.runModal() == .OK, let selectedURL = panel.url else { return false }
            destinationURL = selectedURL
        }

        do {
            try source.write(to: destinationURL, atomically: true, encoding: .utf8)
            fileURL = destinationURL
            isDirty = false
            if projectRootURL == nil {
                projectRootURL = destinationURL.deletingLastPathComponent()
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

    private func loadDocument(at url: URL) throws {
        source = try String(contentsOf: url, encoding: .utf8)
        fileURL = url
        isDirty = false
        compileImmediately()
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
}
