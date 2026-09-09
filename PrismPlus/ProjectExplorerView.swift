import SwiftUI

struct ProjectExplorerView: View {
    @ObservedObject var model: WorkspaceViewModel

    @State private var isRootExpanded = true
    @State private var expandedDirectories: Set<URL> = []
    @State private var folderClickHistory: [URL] = []
    @State private var editOperation: ExplorerEditOperation?
    @State private var editName = ""
    @State private var focusLossTask: Task<Void, Never>?
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            explorerHeader
            Divider()
            if let projectRootURL = model.projectRootURL {
                projectContents(rootURL: projectRootURL)
            } else {
                noFolderView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .controlBackgroundColor))
        .onChange(of: model.projectRootURL) {
            isRootExpanded = true
            expandedDirectories.removeAll()
            folderClickHistory.removeAll()
            cancelEditing()
        }
        .onChange(of: isNameFieldFocused) { _, isFocused in
            focusLossTask?.cancel()
            guard !isFocused, editOperation != nil else { return }
            focusLossTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, !isNameFieldFocused, editOperation != nil else { return }
                resolveActiveEdit()
            }
        }
    }

    private var explorerHeader: some View {
        HStack(spacing: 8) {
            Text("EXPLORER")
                .font(.caption.weight(.semibold))
            Spacer()
            Menu {
                Button("New LaTeX File", systemImage: "doc.badge.plus") {
                    beginCreatingFile()
                }
                .disabled(model.projectRootURL == nil)
                Button("New Folder", systemImage: "folder.badge.plus") {
                    beginCreatingFolder()
                }
                .disabled(model.projectRootURL == nil)
                Divider()
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
    }

    private func projectContents(rootURL: URL) -> some View {
        VStack(spacing: 0) {
            rootRow(rootURL: rootURL)
            if isRootExpanded {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        if editOperation?.createsInside(rootURL) == true {
                            inlineNameEditor(depth: 0)
                        }
                        ForEach(visibleRows) { row in
                            if editOperation?.renames(row.node) == true {
                                inlineNameEditor(depth: row.depth)
                            } else {
                                nodeRow(row)
                            }
                            if editOperation?.createsInside(row.node.url) == true {
                                inlineNameEditor(depth: row.depth + 1)
                            }
                        }
                        if model.projectNodes.isEmpty, editOperation == nil {
                            Text("This folder is empty.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 8)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func rootRow(rootURL: URL) -> some View {
        HStack(spacing: 6) {
            Button {
                guard !consumeExplorerClickIfNeeded() else { return }
                isRootExpanded.toggle()
                if !isRootExpanded {
                    expandedDirectories.removeAll()
                }
            } label: {
                Image(systemName: isRootExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2.weight(.bold))
                    .frame(width: 14, height: 24)
            }
            .help(isRootExpanded ? "Collapse Project" : "Expand Project")

            Button {
                guard !consumeExplorerClickIfNeeded() else { return }
                model.selectExplorerRoot()
            } label: {
                Text(rootURL.lastPathComponent.uppercased())
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }

            Button {
                beginCreatingFile()
            } label: {
                Image(systemName: "doc.badge.plus")
            }
            .help("New LaTeX File")

            Button {
                beginCreatingFolder()
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .help("New Folder")

            Button {
                model.refreshProjectFromUserAction()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh Files")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .frame(height: 34)
        .background(
            model.selectedExplorerDirectoryURL == rootURL
                ? Color.accentColor.opacity(0.16) : Color.clear
        )
        .contentShape(Rectangle())
        .contextMenu {
            rootContextMenu(rootURL: rootURL)
        }
    }

    private var noFolderView: some View {
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

    private var visibleRows: [ExplorerRow] {
        var rows: [ExplorerRow] = []
        appendVisibleRows(model.projectNodes, depth: 0, to: &rows)
        return rows
    }

    private func appendVisibleRows(
        _ nodes: [ProjectNode],
        depth: Int,
        to rows: inout [ExplorerRow]
    ) {
        for node in nodes {
            rows.append(ExplorerRow(node: node, depth: depth))
            if node.isDirectory, expandedDirectories.contains(node.url) {
                appendVisibleRows(node.children ?? [], depth: depth + 1, to: &rows)
            }
        }
    }

    private func nodeRow(_ row: ExplorerRow) -> some View {
        HStack(spacing: 4) {
            if row.node.isDirectory {
                Image(
                    systemName: expandedDirectories.contains(row.node.url)
                        ? "chevron.down" : "chevron.right"
                )
                .font(.caption2.weight(.semibold))
                .frame(width: 12, height: 22)
            } else {
                Color.clear.frame(width: 12, height: 22)
            }

            resourceLabel(for: row.node)
        }
        .padding(.leading, CGFloat(row.depth) * 14)
        .padding(.horizontal, 4)
        .background(selectionColor(for: row.node), in: RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .onTapGesture {
            select(row.node)
        }
        .contextMenu {
            nodeContextMenu(row.node)
        }
    }

    private func resourceLabel(for node: ProjectNode) -> some View {
        HStack(spacing: 7) {
            Image(systemName: fileIcon(for: node))
                .foregroundStyle(resourceColor(for: node))
            Text(node.name)
                .lineLimit(1)
                .foregroundStyle(node.isDirectory || node.isOpenable ? .primary : .tertiary)
            Spacer(minLength: 0)
        }
        .frame(height: 24)
    }

    private func inlineNameEditor(depth: Int) -> some View {
        let showsTexSuffix = editOperation?.usesTexSuffix == true
        return HStack(spacing: 5) {
            Image(systemName: editOperation?.iconName ?? "doc")
                .foregroundStyle(Color.accentColor)
                .frame(width: 15)
            HStack(spacing: 0) {
                TextField(showsTexSuffix ? "filename" : "folder name", text: $editName)
                    .textFieldStyle(.plain)
                    .focused($isNameFieldFocused)
                    .onSubmit(commitEditing)
                if showsTexSuffix {
                    Text(".tex")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 5)
            .frame(height: 23)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.accentColor, lineWidth: 1)
            }
        }
        .padding(.leading, CGFloat(depth) * 14 + 20)
        .padding(.trailing, 5)
        .onExitCommand(perform: cancelEditing)
    }

    @ViewBuilder
    private func rootContextMenu(rootURL: URL) -> some View {
        Button("New LaTeX File", systemImage: "doc.badge.plus") {
            beginCreatingFile(in: rootURL)
        }
        Button("New Folder", systemImage: "folder.badge.plus") {
            beginCreatingFolder(in: rootURL)
        }
        Divider()
        Button("Reveal in Finder", systemImage: "finder") {
            model.revealInFinder(rootURL)
        }
        Button("Refresh", systemImage: "arrow.clockwise") {
            model.refreshProjectFromUserAction()
        }
    }

    @ViewBuilder
    private func nodeContextMenu(_ node: ProjectNode) -> some View {
        if node.isDirectory {
            Button("New LaTeX File", systemImage: "doc.badge.plus") {
                selectFolder(node)
                beginCreatingFile(in: node.url)
            }
            Button("New Folder", systemImage: "folder.badge.plus") {
                selectFolder(node)
                beginCreatingFolder(in: node.url)
            }
            Divider()
        } else if node.isOpenable {
            Button("Open", systemImage: "doc") {
                model.selectProjectNode(node)
            }
            Divider()
        }
        Button("Reveal in Finder", systemImage: "finder") {
            model.revealInFinder(node.url)
        }
        Button("Rename", systemImage: "pencil") {
            beginRenaming(node)
        }
        Divider()
        Button("Move to Trash", systemImage: "trash", role: .destructive) {
            model.moveProjectNodeToTrash(node)
        }
    }

    private func select(_ node: ProjectNode) {
        guard !consumeExplorerClickIfNeeded() else { return }
        if node.isDirectory {
            toggleFolder(node)
        } else if node.isOpenable {
            model.selectProjectNode(node)
        }
    }

    private func selectFolder(_ node: ProjectNode) {
        model.selectExplorerDirectory(node)
        expandedDirectories.insert(node.url)
        recordFolderClick(node.url)
    }

    private func toggleFolder(_ node: ProjectNode) {
        model.selectExplorerDirectory(node)
        recordFolderClick(node.url)
        if expandedDirectories.contains(node.url) {
            let descendantDirectories = Set(
                node.flattened.filter(\.isDirectory).map(\.url)
            )
            expandedDirectories.subtract(descendantDirectories)
        } else {
            expandedDirectories.insert(node.url)
        }
    }

    private func recordFolderClick(_ url: URL) {
        folderClickHistory.removeAll(where: { $0 == url })
        folderClickHistory.append(url)
    }

    private func beginCreatingFile(in requestedDirectory: URL? = nil) {
        guard let directoryURL = creationDirectory(requestedDirectory) else { return }
        isRootExpanded = true
        if directoryURL != model.projectRootURL {
            expandedDirectories.insert(directoryURL)
        }
        editOperation = .createFile(parentURL: directoryURL)
        editName = ""
        focusNameField()
    }

    private func beginCreatingFolder(in requestedDirectory: URL? = nil) {
        guard let directoryURL = creationDirectory(requestedDirectory) else { return }
        isRootExpanded = true
        if directoryURL != model.projectRootURL {
            expandedDirectories.insert(directoryURL)
        }
        editOperation = .createFolder(parentURL: directoryURL)
        editName = ""
        focusNameField()
    }

    private func beginRenaming(_ node: ProjectNode) {
        editOperation = .rename(node)
        editName =
            node.isOpenable ? node.url.deletingPathExtension().lastPathComponent : node.name
        focusNameField()
    }

    private func focusNameField() {
        Task { @MainActor in
            await Task.yield()
            isNameFieldFocused = true
        }
    }

    private func commitEditing() {
        guard let editOperation, !editName.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }
        let succeeded: Bool
        switch editOperation {
        case .createFile(let parentURL):
            succeeded = model.createProjectFile(named: editName, in: parentURL)
        case .createFolder(let parentURL):
            succeeded = model.createProjectFolder(named: editName, in: parentURL)
        case .rename(let node):
            succeeded = model.renameProjectNode(node, to: editName)
        }
        if succeeded {
            cancelEditing()
        } else {
            focusNameField()
        }
    }

    private func cancelEditing() {
        focusLossTask?.cancel()
        focusLossTask = nil
        editOperation = nil
        editName = ""
        isNameFieldFocused = false
    }

    private func creationDirectory(_ requestedDirectory: URL?) -> URL? {
        if let requestedDirectory { return requestedDirectory }
        guard let projectRootURL = model.projectRootURL else { return nil }
        return ExplorerCreationDestination.resolve(
            projectRoot: projectRootURL,
            expandedDirectories: expandedDirectories,
            folderClickHistory: folderClickHistory
        )
    }

    @discardableResult
    private func resolveActiveEdit() -> Bool {
        switch ExplorerEditPolicy.actionForExplorerClick(
            hasActiveEdit: editOperation != nil,
            name: editName
        ) {
        case .performNormally:
            return false
        case .commitAndConsume:
            commitEditing()
            return true
        case .cancelAndConsume:
            cancelEditing()
            return true
        }
    }

    private func consumeExplorerClickIfNeeded() -> Bool {
        resolveActiveEdit()
    }

    private func selectionColor(for node: ProjectNode) -> Color {
        if node.url == model.fileURL { return Color.accentColor.opacity(0.24) }
        if node.url == model.selectedExplorerDirectoryURL {
            return Color.accentColor.opacity(0.16)
        }
        return .clear
    }

    private func resourceColor(for node: ProjectNode) -> Color {
        if node.isDirectory { return .accentColor }
        return node.isOpenable ? .secondary : Color.secondary.opacity(0.55)
    }

    private func fileIcon(for node: ProjectNode) -> String {
        if node.isDirectory {
            return expandedDirectories.contains(node.url)
                ? "folder.fill.badge.minus" : "folder.fill"
        }
        switch node.url.pathExtension.lowercased() {
        case "tex": return "doc.text"
        case "bib": return "books.vertical"
        case "png", "jpg", "jpeg", "svg": return "photo"
        case "pdf": return "doc.richtext"
        default: return "doc"
        }
    }
}

private struct ExplorerRow: Identifiable {
    let node: ProjectNode
    let depth: Int

    var id: URL { node.url }
}

private enum ExplorerEditOperation: Equatable {
    case createFile(parentURL: URL)
    case createFolder(parentURL: URL)
    case rename(ProjectNode)

    var usesTexSuffix: Bool {
        switch self {
        case .createFile: true
        case .rename(let node): node.isOpenable
        case .createFolder: false
        }
    }

    var iconName: String {
        switch self {
        case .createFile: "doc.text"
        case .createFolder: "folder.fill"
        case .rename(let node): node.isDirectory ? "folder.fill" : "doc"
        }
    }

    func createsInside(_ directoryURL: URL) -> Bool {
        switch self {
        case .createFile(let parentURL), .createFolder(let parentURL):
            parentURL == directoryURL
        case .rename:
            false
        }
    }

    func renames(_ node: ProjectNode) -> Bool {
        if case .rename(let renamedNode) = self {
            return renamedNode.url == node.url
        }
        return false
    }
}
