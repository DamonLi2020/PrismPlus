import Foundation
import Testing

@testable import PrismPlus

struct ExplorerCreationDestinationTests {
    @Test("No expanded folder creates at the project root")
    func resolvesRootWhenNoFolderIsExpanded() {
        let root = URL(fileURLWithPath: "/project", isDirectory: true)

        let destination = ExplorerCreationDestination.resolve(
            projectRoot: root,
            expandedDirectories: [],
            folderClickHistory: []
        )

        #expect(destination == root)
    }

    @Test("One expanded folder is always the creation destination")
    func resolvesOnlyExpandedFolder() {
        let root = URL(fileURLWithPath: "/project", isDirectory: true)
        let onlyFolder = root.appendingPathComponent("chapters", isDirectory: true)

        let destination = ExplorerCreationDestination.resolve(
            projectRoot: root,
            expandedDirectories: [onlyFolder],
            folderClickHistory: []
        )

        #expect(destination == onlyFolder)
    }

    @Test("Multiple expanded folders use the most recently clicked open folder")
    func resolvesMostRecentlyClickedExpandedFolder() {
        let root = URL(fileURLWithPath: "/project", isDirectory: true)
        let first = root.appendingPathComponent("first", isDirectory: true)
        let second = root.appendingPathComponent("second", isDirectory: true)
        let folded = root.appendingPathComponent("folded", isDirectory: true)

        let destination = ExplorerCreationDestination.resolve(
            projectRoot: root,
            expandedDirectories: [first, second],
            folderClickHistory: [first, second, folded]
        )

        #expect(destination == second)
    }
}
