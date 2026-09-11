import AppKit
import Foundation
import UniformTypeIdentifiers

enum WorkspaceResourceSelection: Equatable {
    case latexFile(URL)
    case projectFolder(URL)
}

@MainActor
protocol WorkspaceResourcePicking {
    func chooseResource() -> WorkspaceResourceSelection?
}

@MainActor
struct SystemWorkspaceResourcePicker: WorkspaceResourcePicking {
    func chooseResource() -> WorkspaceResourceSelection? {
        let panel = NSOpenPanel()
        panel.title = "Open LaTeX File or Folder"
        panel.message =
            "Choose a .tex file or project folder, or open the folder currently shown below."
        panel.allowedContentTypes = [UTType(filenameExtension: "tex") ?? .plainText]
        panel.allowsOtherFileTypes = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false

        let accessoryController = CurrentFolderAccessoryController(panel: panel)
        panel.delegate = accessoryController
        panel.accessoryView = accessoryController.view
        panel.isAccessoryViewDisclosed = true

        let response = panel.runModal()
        let standardSelection = response == .OK ? panel.url : nil
        guard
            let selectedURL = ProjectFolderPickerResult.resolve(
                standardSelection: standardSelection,
                currentFolderSelection: accessoryController.selectedFolderURL
            )
        else {
            return nil
        }

        let values = try? selectedURL.resourceValues(forKeys: [.isDirectoryKey])
        if values?.isDirectory == true {
            return .projectFolder(selectedURL)
        }

        guard selectedURL.pathExtension.lowercased() == "tex" else { return nil }
        return .latexFile(selectedURL)
    }
}

@MainActor
protocol ProjectFolderPicking {
    func chooseFolder() -> URL?
}

enum ProjectFolderPickerResult {
    static func resolve(
        standardSelection: URL?,
        currentFolderSelection: URL?
    ) -> URL? {
        currentFolderSelection ?? standardSelection
    }
}

@MainActor
struct SystemProjectFolderPicker: ProjectFolderPicking {
    func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Open LaTeX Project"
        panel.message = "Choose a project folder, or open the folder currently shown below."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        let accessoryController = CurrentFolderAccessoryController(panel: panel)
        panel.delegate = accessoryController
        panel.accessoryView = accessoryController.view
        panel.isAccessoryViewDisclosed = true

        let response = panel.runModal()
        let standardSelection = response == .OK ? panel.url : nil
        return ProjectFolderPickerResult.resolve(
            standardSelection: standardSelection,
            currentFolderSelection: accessoryController.selectedFolderURL
        )
    }
}

@MainActor
private final class CurrentFolderAccessoryController: NSObject, NSOpenSavePanelDelegate {
    private weak var panel: NSOpenPanel?
    private let openCurrentFolderButton: NSButton
    private(set) var selectedFolderURL: URL?
    let view: NSView

    init(panel: NSOpenPanel) {
        self.panel = panel

        let explanation = NSTextField(labelWithString: "Open the location currently shown:")
        explanation.textColor = .secondaryLabelColor

        openCurrentFolderButton = NSButton(title: "Open Current Folder", target: nil, action: nil)
        openCurrentFolderButton.bezelStyle = .rounded

        let stack = NSStackView(views: [explanation, openCurrentFolderButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        view = stack

        super.init()

        openCurrentFolderButton.target = self
        openCurrentFolderButton.action = #selector(chooseCurrentFolder)
        updateButtonTitle(for: panel.directoryURL)
    }

    func panel(_ sender: Any, didChangeToDirectoryURL url: URL?) {
        updateButtonTitle(for: url)
    }

    @objc
    private func chooseCurrentFolder() {
        guard let panel, let directoryURL = panel.directoryURL else { return }
        selectedFolderURL = directoryURL
        panel.cancel(nil)
    }

    private func updateButtonTitle(for url: URL?) {
        guard let folderName = url?.lastPathComponent, !folderName.isEmpty else {
            openCurrentFolderButton.title = "Open Current Folder"
            return
        }
        openCurrentFolderButton.title = "Open “\(folderName)”"
    }
}
