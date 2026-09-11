import Foundation

struct ProjectNode: Identifiable, Equatable, Sendable {
    let url: URL
    let isDirectory: Bool
    let children: [ProjectNode]?

    var id: URL { url }
    var name: String { url.lastPathComponent }
    var isOpenable: Bool { !isDirectory && url.pathExtension.lowercased() == "tex" }

    var flattened: [ProjectNode] {
        [self] + (children ?? []).flatMap(\.flattened)
    }

    func replacingChildren(of directoryURL: URL, with updatedChildren: [ProjectNode]) -> Self {
        if url == directoryURL {
            return ProjectNode(url: url, isDirectory: isDirectory, children: updatedChildren)
        }
        guard let children else { return self }
        return ProjectNode(
            url: url,
            isDirectory: isDirectory,
            children: children.map {
                $0.replacingChildren(of: directoryURL, with: updatedChildren)
            }
        )
    }
}

enum ProjectScanner {
    private static let ignoredDirectories: Set<String> = [
        ".build", ".git", "build", "DerivedData",
    ]

    static func scan(rootURL: URL) throws -> [ProjectNode] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: [.skipsHiddenFiles]
        )

        let nodes = try urls.compactMap { url -> ProjectNode? in
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey])
            guard values.isHidden != true else { return nil }

            if values.isDirectory == true {
                guard !ignoredDirectories.contains(url.lastPathComponent) else { return nil }
                return ProjectNode(url: url, isDirectory: true, children: nil)
            }

            return ProjectNode(url: url, isDirectory: false, children: nil)
        }

        return nodes.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}
