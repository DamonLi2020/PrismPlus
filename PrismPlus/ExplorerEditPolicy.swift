import Foundation

enum ExplorerEditClickAction: Equatable {
    case performNormally
    case commitAndConsume
    case cancelAndConsume
}

enum ExplorerEditPolicy {
    static func actionForExplorerClick(
        hasActiveEdit: Bool,
        name: String
    ) -> ExplorerEditClickAction {
        guard hasActiveEdit else { return .performNormally }
        return name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? .cancelAndConsume : .commitAndConsume
    }
}

enum ExplorerCreationDestination {
    static func resolve(
        projectRoot: URL,
        expandedDirectories: Set<URL>,
        folderClickHistory: [URL]
    ) -> URL {
        if expandedDirectories.isEmpty { return projectRoot }
        if expandedDirectories.count == 1 { return expandedDirectories.first ?? projectRoot }
        return folderClickHistory.last(where: expandedDirectories.contains) ?? projectRoot
    }
}
