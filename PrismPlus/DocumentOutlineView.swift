import SwiftUI

struct DocumentOutlineVisibleRow: Identifiable, Equatable {
    let item: LaTeXOutlineItem
    let depth: Int

    var id: String { item.id }
    var title: String { item.title }
    var hasChildren: Bool { !item.children.isEmpty }
}

enum DocumentOutlinePresentation {
    static func collapsibleItemIDs(in items: [LaTeXOutlineItem]) -> Set<String> {
        Set(
            items.flatMap { item in
                (item.children.isEmpty ? [] : [item.id])
                    + Array(collapsibleItemIDs(in: item.children))
            }
        )
    }

    static func allItemIDs(in items: [LaTeXOutlineItem]) -> Set<String> {
        Set(items.flatMap { [$0.id] + Array(allItemIDs(in: $0.children)) })
    }

    static func visibleRows(
        in items: [LaTeXOutlineItem],
        expandedIDs: Set<String>,
        depth: Int = 0
    ) -> [DocumentOutlineVisibleRow] {
        items.flatMap { item in
            let row = DocumentOutlineVisibleRow(item: item, depth: depth)
            guard !item.children.isEmpty, expandedIDs.contains(item.id) else { return [row] }
            return [row]
                + visibleRows(
                    in: item.children,
                    expandedIDs: expandedIDs,
                    depth: depth + 1
                )
        }
    }
}

struct DocumentOutlineView: View {
    let items: [LaTeXOutlineItem]
    @Binding var isExpanded: Bool
    let onSelect: (Int) -> Void

    @State private var expandedItemIDs: Set<String>
    @State private var knownItemIDs: Set<String>

    init(
        items: [LaTeXOutlineItem],
        isExpanded: Binding<Bool>,
        onSelect: @escaping (Int) -> Void
    ) {
        self.items = items
        _isExpanded = isExpanded
        self.onSelect = onSelect
        _expandedItemIDs = State(
            initialValue: DocumentOutlinePresentation.collapsibleItemIDs(in: items)
        )
        _knownItemIDs = State(initialValue: DocumentOutlinePresentation.allItemIDs(in: items))
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2.weight(.bold))
                    Text("DOCUMENT OUTLINE")
                        .font(.caption.weight(.semibold))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .frame(height: 34)

            if isExpanded {
                Divider()
                if items.isEmpty {
                    Text("Add a section heading to build an outline.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                    Spacer(minLength: 0)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(visibleRows) { row in
                                outlineRow(row)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onChange(of: items) { _, updatedItems in
            let updatedIDs = DocumentOutlinePresentation.allItemIDs(in: updatedItems)
            let newlyAddedIDs = updatedIDs.subtracting(knownItemIDs)
            let newParentIDs = DocumentOutlinePresentation.collapsibleItemIDs(in: updatedItems)
                .intersection(newlyAddedIDs)
            expandedItemIDs.formIntersection(updatedIDs)
            expandedItemIDs.formUnion(newParentIDs)
            knownItemIDs = updatedIDs
        }
    }

    private var visibleRows: [DocumentOutlineVisibleRow] {
        DocumentOutlinePresentation.visibleRows(
            in: items,
            expandedIDs: expandedItemIDs
        )
    }

    private func outlineRow(_ row: DocumentOutlineVisibleRow) -> some View {
        HStack(spacing: 4) {
            indentation(for: row.depth)

            if row.hasChildren {
                Button {
                    toggleExpansion(for: row.item)
                } label: {
                    Image(
                        systemName: expandedItemIDs.contains(row.id)
                            ? "chevron.down" : "chevron.right"
                    )
                    .font(.caption2.weight(.semibold))
                    .frame(width: 14, height: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 14, height: 28)
            }

            Button {
                onSelect(row.item.line)
            } label: {
                HStack(spacing: 3) {
                    Text(row.item.title)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if row.item.isUnnumbered {
                        Text("*")
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 4)
                    Text("\(row.item.line)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(height: 28)
        .overlay(alignment: .leading) {
            indentationGuides(for: row.depth)
                .allowsHitTesting(false)
        }
    }

    private func indentation(for depth: Int) -> some View {
        Color.clear.frame(width: CGFloat(depth) * 18, height: 28)
    }

    private func indentationGuides(for depth: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<depth, id: \.self) { _ in
                Rectangle()
                    .fill(Color.secondary.opacity(0.28))
                    .frame(width: 1)
                    .padding(.leading, 7)
                    .frame(width: 18, alignment: .leading)
            }
            Spacer(minLength: 0)
        }
    }

    private func toggleExpansion(for item: LaTeXOutlineItem) {
        if expandedItemIDs.contains(item.id) {
            expandedItemIDs.remove(item.id)
        } else {
            expandedItemIDs.insert(item.id)
        }
    }
}
