import SwiftUI

struct WorkspaceView: View {
    @StateObject private var model = WorkspaceViewModel()
    @State private var formatRequestID = 0
    @State private var isExplorerVisible = true
    @State private var navigationRequest: EditorNavigationRequest?
    @State private var nextNavigationRequestID = 0

    var body: some View {
        VStack(spacing: 0) {
            workspaceHeader
            Divider()
            HStack(spacing: 0) {
                activityBar
                Divider()
                if isExplorerVisible {
                    HSplitView {
                        projectSidebar
                            .frame(minWidth: 210, idealWidth: 250, maxWidth: 340)
                        mainWorkspace
                    }
                } else {
                    mainWorkspace
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1_100, maxWidth: .infinity, minHeight: 640, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: .compileLaTeXDocument)) { _ in
            model.compileImmediately()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newLaTeXDocument)) { _ in
            model.newDocument()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openLaTeXDocument)) { _ in
            model.openDocument()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openLaTeXProject)) { _ in
            model.openProject()
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveLaTeXDocument)) { _ in
            model.saveDocument()
        }
        .onReceive(NotificationCenter.default.publisher(for: .formatLaTeXDocument)) { _ in
            formatRequestID += 1
        }
    }

    private var activityBar: some View {
        VStack(spacing: 8) {
            Button {
                isExplorerVisible.toggle()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 21, weight: .medium))
                    .frame(width: 46, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(isExplorerVisible ? Color.accentColor : Color.secondary)
            .background(
                isExplorerVisible ? Color.accentColor.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(alignment: .leading) {
                if isExplorerVisible {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2, height: 30)
                }
            }
            .help(isExplorerVisible ? "Hide Explorer" : "Show Explorer")

            Spacer()

            Image(systemName: "gearshape")
                .font(.system(size: 19))
                .foregroundStyle(.tertiary)
                .frame(width: 46, height: 44)
                .help("Settings will be added in a later milestone")
        }
        .padding(.vertical, 6)
        .frame(width: 50)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var mainWorkspace: some View {
        Group {
            if model.hasOpenDocument {
                HSplitView {
                    editorPane
                        .frame(minWidth: 480, idealWidth: 680, maxHeight: .infinity)
                    previewPane
                        .frame(minWidth: 360, idealWidth: 520, maxHeight: .infinity)
                }
            } else {
                welcomePage
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var projectSidebar: some View {
        if model.hasOpenDocument {
            VSplitView {
                ProjectExplorerView(model: model)
                    .frame(minHeight: 220, idealHeight: 440, maxHeight: .infinity)
                DocumentOutlineView(items: model.outlineItems) { line in
                    navigateToSourceLine(line)
                }
                .frame(minHeight: 120, idealHeight: 220, maxHeight: .infinity)
            }
        } else {
            ProjectExplorerView(model: model)
                .frame(maxHeight: .infinity)
        }
    }

    private var welcomePage: some View {
        ZStack {
            Color(red: 0.055, green: 0.063, blue: 0.082)
            HStack {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(spacing: 16) {
                        Image(systemName: "doc.richtext.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Prism Plus")
                                .font(.system(size: 34, weight: .semibold))
                            Text("A focused, local LaTeX workspace")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Start")
                            .font(.title2.weight(.semibold))
                        welcomeAction("New LaTeX Document", systemImage: "doc.badge.plus") {
                            model.newDocument()
                        }
                        welcomeAction("Open LaTeX File…", systemImage: "doc") {
                            model.openDocument()
                        }
                        welcomeAction("Open Folder…", systemImage: "folder") {
                            model.openProject()
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Only .tex files open in the editor", systemImage: "checkmark.circle")
                        Label(
                            "All project resources stay visible in Explorer", systemImage: "folder")
                        Label("Documents remain local on this Mac", systemImage: "lock")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 620, alignment: .leading)
                Spacer(minLength: 40)
            }
            .padding(64)
        }
    }

    private func welcomeAction(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(minWidth: 220, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private var workspaceHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .foregroundStyle(.tint)
            Text(model.documentTitle)
                .font(.headline)
            Spacer()
            if model.hasOpenDocument {
                buildStatus
                Button {
                    model.compileImmediately()
                } label: {
                    Label("Compile", systemImage: "play.fill")
                }
                .keyboardShortcut("b")
                .disabled(model.buildState == .compiling)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(.bar)
    }

    private var buildStatus: some View {
        HStack(spacing: 6) {
            if model.buildState == .compiling {
                ProgressView()
                    .controlSize(.small)
            } else {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            Text(model.buildState.label)
                .foregroundStyle(.secondary)
        }
        .font(.callout)
    }

    private var editorPane: some View {
        VStack(spacing: 0) {
            sourceHeader
            MonacoEditorView(
                text: model.source,
                formatRequestID: formatRequestID,
                navigationRequest: navigationRequest,
                diagnostics: model.diagnostics
            ) {
                source, deferAutomaticCompilation in
                model.updateSource(
                    source,
                    deferAutomaticCompilation: deferAutomaticCompilation
                )
            }
            HStack {
                Text("Suggestions, snippets, pairing, formatting, and syntax highlighting enabled")
                Spacer()
                Text("⌘⇧F: Format • ⌃Space: Suggestions")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Color.black.opacity(0.2))
            diagnosticsPanel
        }
        .background(Color(red: 0.055, green: 0.063, blue: 0.082))
        .frame(maxHeight: .infinity)
    }

    private var sourceHeader: some View {
        HStack {
            paneLabel("SOURCE", detail: "LaTeX")
            Spacer()
            Button {
                formatRequestID += 1
            } label: {
                Label("Format", systemImage: "text.alignleft")
            }
            .buttonStyle(.plain)
            .help("Format Document (⌘⇧F)")
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(.bar)
    }

    @ViewBuilder
    private var diagnosticsPanel: some View {
        if !model.diagnostics.isEmpty {
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 7) {
                    ForEach(model.diagnostics) { diagnostic in
                        if let line = diagnostic.line {
                            Button {
                                navigateToSourceLine(line)
                            } label: {
                                diagnosticRow(diagnostic)
                            }
                            .buttonStyle(.plain)
                            .help("Jump to line \(line)")
                        } else {
                            diagnosticRow(diagnostic)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
            }
            .frame(maxHeight: 150)
            .background(Color.black.opacity(0.18))
        }
    }

    private func diagnosticRow(_ diagnostic: CompilationDiagnostic) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(
                systemName: diagnostic.severity == .error
                    ? "xmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .foregroundStyle(diagnostic.severity == .error ? Color.red : Color.orange)
            Text(diagnostic.line.map { "Line \($0): " } ?? "")
                .foregroundStyle(.secondary)
            Text(diagnostic.message)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .font(.system(size: 12, design: .monospaced))
        .contentShape(Rectangle())
    }

    private func navigateToSourceLine(_ line: Int) {
        nextNavigationRequestID += 1
        navigationRequest = EditorNavigationRequest(
            id: nextNavigationRequestID,
            line: line
        )
    }

    private var previewPane: some View {
        VStack(spacing: 0) {
            previewHeader
            if let pdfData = model.pdfData {
                PDFPreview(data: pdfData)
            } else {
                ContentUnavailableView {
                    Label("No Preview Yet", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("Prism Plus will show the last successful PDF here.")
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(maxHeight: .infinity)
    }

    private var previewHeader: some View {
        HStack {
            paneLabel("PREVIEW", detail: "PDF")
            Spacer()
            Menu {
                Button("Download PDF…", systemImage: "arrow.down.doc") {
                    model.downloadPDF()
                }
                .disabled(!model.canDownloadPDF)
                Button("Save PDF Next to Source", systemImage: "doc.badge.plus") {
                    model.savePDFBesideSource()
                }
                .disabled(!model.canSavePDFBesideSource)
            } label: {
                Label("Export", systemImage: "square.and.arrow.down")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(!model.canDownloadPDF)
            .help("Download or save the compiled PDF")
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(.bar)
    }

    private func paneLabel(_ title: String, detail: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var statusColor: Color {
        switch model.buildState {
        case .idle: .secondary
        case .waiting: .orange
        case .compiling: .blue
        case .succeeded: .green
        case .failed: .red
        }
    }

}
