import SwiftUI

struct WorkspaceView: View {
    @StateObject private var model = WorkspaceViewModel()
    @State private var formatRequestID = 0
    @State private var isExplorerVisible = true
    @State private var isProjectTreeExpanded = true

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
        }
        .frame(minWidth: 1_100, minHeight: 640)
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

    @ViewBuilder
    private var mainWorkspace: some View {
        if model.hasOpenDocument {
            HSplitView {
                editorPane
                    .frame(minWidth: 480, idealWidth: 680)
                previewPane
                    .frame(minWidth: 360, idealWidth: 520)
            }
        } else {
            welcomePage
        }
    }

    private var projectSidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("EXPLORER")
                    .font(.caption.weight(.semibold))
                Spacer()
                Menu {
                    Button("New LaTeX File…", systemImage: "doc.badge.plus") {
                        model.createProjectFile()
                    }
                    .disabled(model.projectRootURL == nil)
                    Button("Open LaTeX File…", systemImage: "doc") {
                        model.openDocument()
                    }
                    Button("Open Folder…", systemImage: "folder") {
                        model.openProject()
                    }
                    Divider()
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        model.refreshProjectFromUserAction()
                    }
                    .disabled(model.projectRootURL == nil)
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .help("Explorer Actions")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .frame(height: 40)

            Divider()

            if let projectRootURL = model.projectRootURL {
                HStack(spacing: 6) {
                    Button {
                        isProjectTreeExpanded.toggle()
                    } label: {
                        Image(
                            systemName: isProjectTreeExpanded
                                ? "chevron.down" : "chevron.right"
                        )
                        .font(.caption2.weight(.bold))
                    }
                    .buttonStyle(.plain)
                    Button {
                        isProjectTreeExpanded.toggle()
                    } label: {
                        Text(projectRootURL.lastPathComponent.uppercased())
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button {
                        model.createProjectFile()
                    } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                    .help("New LaTeX File")
                    Button {
                        model.refreshProjectFromUserAction()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh Files")
                }
                .padding(.horizontal, 10)
                .frame(height: 34)

                if isProjectTreeExpanded {
                    if model.projectNodes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("This folder is empty.")
                            Button("New LaTeX File…") {
                                model.createProjectFile()
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        resourceTree
                    }
                }
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text("NO FOLDER OPENED")
                        .font(.caption.weight(.bold))
                    Text("You have not yet opened a folder.")
                        .font(.callout)
                    Button("Open Folder") {
                        model.openProject()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    Text(
                        "Only .tex documents can be opened. Other project resources remain visible in light gray for context."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var resourceTree: some View {
        ScrollView {
            OutlineGroup(model.projectNodes, children: \.children) { node in
                resourceRow(for: node)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func resourceRow(for node: ProjectNode) -> some View {
        if node.isDirectory {
            resourceLabel(for: node)
        } else if node.isOpenable {
            Button {
                model.selectProjectNode(node)
            } label: {
                resourceLabel(for: node)
            }
            .buttonStyle(.plain)
        } else {
            resourceLabel(for: node)
                .foregroundStyle(Color.secondary.opacity(0.55))
                .allowsHitTesting(false)
                .help("Prism Plus opens only .tex documents")
        }
    }

    private func resourceLabel(for node: ProjectNode) -> some View {
        HStack(spacing: 7) {
            Image(systemName: fileIcon(for: node))
                .foregroundStyle(
                    node.isDirectory
                        ? Color.accentColor
                        : node.isOpenable ? Color.secondary : Color.secondary.opacity(0.55)
                )
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
