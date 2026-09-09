import Foundation

enum ProjectResourceKind: Equatable, Sendable {
    case latexFile
    case folder
    case otherFile
}

enum ProjectResourceError: LocalizedError {
    case emptyName
    case invalidName
    case outsideProject
    case alreadyExists(String)

    var errorDescription: String? {
        switch self {
        case .emptyName:
            "Enter a name."
        case .invalidName:
            "Names cannot be '.', '..', or contain '/'."
        case .outsideProject:
            "Prism Plus can manage resources only inside the open project."
        case .alreadyExists(let name):
            "A file or folder named '\(name)' already exists."
        }
    }
}

enum ProjectResourceManager {
    static func create(
        named rawName: String,
        kind: ProjectResourceKind,
        in directoryURL: URL,
        projectRoot: URL
    ) throws -> URL {
        try requireInsideProject(directoryURL, projectRoot: projectRoot)
        let name = try normalizedName(rawName, kind: kind)
        let destinationURL = directoryURL.appendingPathComponent(
            name,
            isDirectory: kind == .folder
        )
        try requireInsideProject(destinationURL, projectRoot: projectRoot)
        guard !FileManager.default.fileExists(atPath: destinationURL.path) else {
            throw ProjectResourceError.alreadyExists(name)
        }

        if kind == .folder {
            try FileManager.default.createDirectory(
                at: destinationURL,
                withIntermediateDirectories: false
            )
        } else {
            let contents =
                kind == .latexFile
                ? Data(LaTeXDocumentTemplate.standard.utf8)
                : Data()
            try contents.write(to: destinationURL, options: .withoutOverwriting)
        }
        return destinationURL
    }

    static func rename(
        _ sourceURL: URL,
        to rawName: String,
        as kind: ProjectResourceKind,
        projectRoot: URL
    ) throws -> URL {
        try requireInsideProject(sourceURL, projectRoot: projectRoot)
        let name = try normalizedName(rawName, kind: kind)
        let destinationURL = sourceURL.deletingLastPathComponent().appendingPathComponent(
            name,
            isDirectory: kind == .folder
        )
        try requireInsideProject(destinationURL, projectRoot: projectRoot)
        if destinationURL.standardizedFileURL == sourceURL.standardizedFileURL {
            return sourceURL
        }
        guard !FileManager.default.fileExists(atPath: destinationURL.path) else {
            throw ProjectResourceError.alreadyExists(name)
        }
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    static func moveToTrash(_ resourceURL: URL, projectRoot: URL) throws {
        try requireInsideProject(resourceURL, projectRoot: projectRoot)
        guard resourceURL.standardizedFileURL != projectRoot.standardizedFileURL else {
            throw ProjectResourceError.outsideProject
        }
        try FileManager.default.trashItem(at: resourceURL, resultingItemURL: nil)
    }

    static func kind(for node: ProjectNode) -> ProjectResourceKind {
        if node.isDirectory { return .folder }
        return node.isOpenable ? .latexFile : .otherFile
    }

    private static func normalizedName(
        _ rawName: String,
        kind: ProjectResourceKind
    ) throws -> String {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ProjectResourceError.emptyName }
        guard name != ".", name != "..", !name.contains("/"), !name.contains("\0") else {
            throw ProjectResourceError.invalidName
        }
        if kind == .latexFile, !name.lowercased().hasSuffix(".tex") {
            return "\(name).tex"
        }
        return name
    }

    private static func requireInsideProject(_ url: URL, projectRoot: URL) throws {
        let candidatePath = url.standardizedFileURL.resolvingSymlinksInPath().path
        let rootPath = projectRoot.standardizedFileURL.resolvingSymlinksInPath().path
        let rootPrefix = rootPath.hasSuffix("/") ? rootPath : "\(rootPath)/"
        guard candidatePath == rootPath || candidatePath.hasPrefix(rootPrefix) else {
            throw ProjectResourceError.outsideProject
        }
    }
}
