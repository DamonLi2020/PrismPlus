import Testing

@testable import PrismPlus

struct DocumentOutlineSidebarLayoutTests {
    @Test("An unavailable outline leaves the Explorer as the only sidebar pane")
    func unavailableOutlineUsesExplorerOnly() {
        let layout = DocumentOutlineSidebarLayout(
            isOutlineAvailable: false,
            isOutlineExpanded: true
        )

        #expect(layout == .explorerOnly)
    }

    @Test("A collapsed outline uses a fixed footer instead of a split pane")
    func collapsedOutlineUsesFixedFooter() {
        let layout = DocumentOutlineSidebarLayout(
            isOutlineAvailable: true,
            isOutlineExpanded: false
        )

        #expect(layout == .explorerWithCollapsedOutline)
    }

    @Test("An expanded outline uses the resizable split pane")
    func expandedOutlineUsesSplitPane() {
        let layout = DocumentOutlineSidebarLayout(
            isOutlineAvailable: true,
            isOutlineExpanded: true
        )

        #expect(layout == .explorerWithExpandedOutline)
    }
}
