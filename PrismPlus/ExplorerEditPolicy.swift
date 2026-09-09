import Foundation

enum ExplorerEditPolicy {
    static func shouldCancelWhenFocusLeaves(name: String) -> Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
