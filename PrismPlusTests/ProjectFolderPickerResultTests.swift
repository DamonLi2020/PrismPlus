import Foundation
import Testing

@testable import PrismPlus

struct ProjectFolderPickerResultTests {
    @Test("The current-folder action can choose a Finder sidebar destination")
    func resolvesCurrentFolderSelection() {
        let desktop = URL(fileURLWithPath: "/Users/test/Desktop", isDirectory: true)

        let result = ProjectFolderPickerResult.resolve(
            standardSelection: nil,
            currentFolderSelection: desktop
        )

        #expect(result == desktop)
    }

    @Test("The standard selected folder remains supported")
    func resolvesStandardSelection() {
        let project = URL(fileURLWithPath: "/Users/test/Desktop/Project", isDirectory: true)

        let result = ProjectFolderPickerResult.resolve(
            standardSelection: project,
            currentFolderSelection: nil
        )

        #expect(result == project)
    }
}
