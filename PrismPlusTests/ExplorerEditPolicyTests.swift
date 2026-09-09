import Testing

@testable import PrismPlus

struct ExplorerEditPolicyTests {
    @Test("An unnamed inline resource is cancelled when focus leaves")
    func cancelsEmptyInlineCreation() {
        #expect(ExplorerEditPolicy.shouldCancelWhenFocusLeaves(name: ""))
        #expect(ExplorerEditPolicy.shouldCancelWhenFocusLeaves(name: "   "))
        #expect(!ExplorerEditPolicy.shouldCancelWhenFocusLeaves(name: "chapter"))
    }
}
