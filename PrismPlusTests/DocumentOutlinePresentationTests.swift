import Testing

@testable import PrismPlus

struct DocumentOutlinePresentationTests {
    @Test("Expanded outline rows preserve heading depth for indentation guides")
    func expandedRowsPreserveDepth() {
        let items = sampleOutline()
        let expandedIDs = DocumentOutlinePresentation.collapsibleItemIDs(in: items)

        let rows = DocumentOutlinePresentation.visibleRows(
            in: items,
            expandedIDs: expandedIDs
        )

        #expect(rows.map(\.title) == ["Introduction", "Examples", "Figures", "Conclusion"])
        #expect(rows.map(\.depth) == [0, 0, 1, 0])
        #expect(rows.map(\.hasChildren) == [false, true, false, false])
    }

    @Test("Collapsing a parent hides only its descendants")
    func collapsedParentHidesDescendants() {
        let items = sampleOutline()

        let rows = DocumentOutlinePresentation.visibleRows(
            in: items,
            expandedIDs: []
        )

        #expect(rows.map(\.title) == ["Introduction", "Examples", "Conclusion"])
        #expect(rows.allSatisfy { $0.depth == 0 })
    }

    private func sampleOutline() -> [LaTeXOutlineItem] {
        [
            item("Introduction", id: "intro", line: 1),
            item(
                "Examples",
                id: "examples",
                line: 2,
                children: [item("Figures", id: "figures", line: 3)]
            ),
            item("Conclusion", id: "conclusion", line: 4),
        ]
    }

    private func item(
        _ title: String,
        id: String,
        line: Int,
        children: [LaTeXOutlineItem] = []
    ) -> LaTeXOutlineItem {
        LaTeXOutlineItem(
            id: id,
            title: title,
            command: "section",
            line: line,
            isUnnumbered: false,
            children: children
        )
    }
}
