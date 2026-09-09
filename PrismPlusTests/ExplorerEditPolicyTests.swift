import Testing

@testable import PrismPlus

struct ExplorerEditPolicyTests {
    @Test("The first click away commits a name or cancels an empty placeholder")
    func resolvesFirstClickAway() {
        #expect(
            ExplorerEditPolicy.actionForExplorerClick(hasActiveEdit: true, name: "")
                == .cancelAndConsume
        )
        #expect(
            ExplorerEditPolicy.actionForExplorerClick(hasActiveEdit: true, name: "   ")
                == .cancelAndConsume
        )
        #expect(
            ExplorerEditPolicy.actionForExplorerClick(hasActiveEdit: true, name: "chapter")
                == .commitAndConsume
        )
        #expect(
            ExplorerEditPolicy.actionForExplorerClick(hasActiveEdit: false, name: "")
                == .performNormally
        )
    }
}
