import SwiftUI

struct WorkspaceView: View {
    @StateObject private var model = WorkspaceViewModel()
    @State private var formatRequestID = 0

    var body: some View {
        VStack(spacing: 0) {
            workspaceHeader
            Divider()
            HSplitView {
                projectSidebar
                    .frame(minWidth: 190, idealWidth: 230, maxWidth: 300)
                editorPane
                    .frame(minWidth: 480, idealWidth: 680)
                previewPane
                    .frame(minWidth: 360, idealWidth: 520)
            }
        }
        .frame(minWidth: 1_100, minHeight: 640)
        .onAppear { model.compileImmediately() }
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

    private var projectSidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("EXPLORER")
                        .font(.caption.weight(.semibold))
                    Text(model.projectRootURL?.lastPathComponent ?? "No project open")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    model.openProject()
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .help("Open Project")
                Button {
                    model.createProjectFile()
                } label: {
                    Image(systemName: "doc.badge.plus")
                }
                .help("New LaTeX File")
                .disabled(model.projectRootURL == nil)
                Button {
                    model.refreshProjectFromUserAction()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh Files")
                .disabled(model.projectRootURL == nil)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .frame(height: 48)

            Divider()

            if model.projectNodes.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "folder")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Open a folder to manage a multi-file LaTeX project.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Open Project…") {
                        model.openProject()
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    OutlineGroup(model.projectNodes, children: \.children) { node in
                        Button {
                            model.selectProjectNode(node)
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: fileIcon(for: node))
                                    .foregroundStyle(
                                        node.isDirectory ? Color.accentColor : .secondary)
                                Text(node.name)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(
                                node.url == model.fileURL
                                    ? Color.accentColor.opacity(0.24) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 4)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var workspaceHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .foregroundStyle(.tint)
            Text(model.documentTitle)
                .font(.headline)
            Spacer()
            buildStatus
            Button {
                model.compileImmediately()
            } label: {
                Label("Compile", systemImage: "play.fill")
            }
            .keyboardShortcut("b")
            .disabled(model.buildState == .compiling)
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
            paneTitle("SOURCE", detail: "LaTeX")
            MonacoEditorView(text: model.source, formatRequestID: formatRequestID) {
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
    }

    @ViewBuilder
    private var diagnosticsPanel: some View {
        if !model.diagnostics.isEmpty {
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 7) {
                    ForEach(model.diagnostics) { diagnostic in
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Image(
                                systemName: diagnostic.severity == .error
                                    ? "xmark.circle.fill" : "exclamationmark.triangle.fill"
                            )
                            .foregroundStyle(
                                diagnostic.severity == .error ? Color.red : Color.orange
                            )
                            Text(diagnostic.line.map { "Line \($0): " } ?? "")
                                .foregroundStyle(.secondary)
                            Text(diagnostic.message)
                                .textSelection(.enabled)
                        }
                        .font(.system(size: 12, design: .monospaced))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
            }
            .frame(maxHeight: 150)
            .background(Color.black.opacity(0.18))
        }
    }

    private var previewPane: some View {
        VStack(spacing: 0) {
            paneTitle("PREVIEW", detail: "PDF")
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
    }

    private func paneTitle(_ title: String, detail: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(.bar)
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

    private func fileIcon(for node: ProjectNode) -> String {
        if node.isDirectory { return "folder.fill" }
        switch node.url.pathExtension.lowercased() {
        case "tex": return "doc.text"
        case "bib": return "books.vertical"
        case "png", "jpg", "jpeg", "svg": return "photo"
        case "pdf": return "doc.richtext"
        default: return "doc"
        }
    }
}
