import SwiftUI

struct DocumentOutlineView: View {
    let items: [LaTeXOutlineItem]
    let onSelect: (Int) -> Void

    @State private var isExpanded = true

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
                        OutlineGroup(items, children: \.outlineChildren) { item in
                            Button {
                                onSelect(item.line)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: iconName(for: item.command))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(item.title)
                                        .lineLimit(1)
                                    if item.isUnnumbered {
                                        Text("*")
                                            .foregroundStyle(.tertiary)
                                    }
                                    Spacer(minLength: 0)
                                    Text("\(item.line)")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .frame(height: 24)
                        }
                        .padding(.leading, 16)
                        .padding(.trailing, 8)
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func iconName(for command: String) -> String {
        switch command {
        case "book", "part", "chapter": "book.closed"
        case "section": "text.alignleft"
        default: "text.line.first.and.arrowtriangle.forward"
        }
    }
}
