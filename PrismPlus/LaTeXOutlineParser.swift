import Foundation

struct LaTeXOutlineItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let command: String
    let line: Int
    let isUnnumbered: Bool
    let children: [LaTeXOutlineItem]

    var outlineChildren: [LaTeXOutlineItem]? {
        children.isEmpty ? nil : children
    }
}

enum LaTeXOutlineParser {
    private struct Heading {
        let title: String
        let command: String
        let level: Int
        let line: Int
        let isUnnumbered: Bool
    }

    private final class Node {
        let heading: Heading
        var children: [Node] = []

        init(heading: Heading) {
            self.heading = heading
        }

        func value() -> LaTeXOutlineItem {
            LaTeXOutlineItem(
                id: "\(heading.line):\(heading.command):\(heading.title)",
                title: heading.title,
                command: heading.command,
                line: heading.line,
                isUnnumbered: heading.isUnnumbered,
                children: children.map { $0.value() }
            )
        }
    }

    private static let headingLevels = [
        "book": 0,
        "part": 1,
        "chapter": 2,
        "section": 3,
        "subsection": 4,
        "subsubsection": 5,
        "paragraph": 6,
        "subparagraph": 7,
    ]

    static func parse(_ source: String) -> [LaTeXOutlineItem] {
        let headings = source.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .compactMap { offset, line in
                parseHeading(in: String(line), lineNumber: offset + 1)
            }

        var roots: [Node] = []
        var ancestors: [(level: Int, node: Node)] = []
        for heading in headings {
            while let ancestor = ancestors.last, ancestor.level >= heading.level {
                ancestors.removeLast()
            }
            let node = Node(heading: heading)
            if let parent = ancestors.last?.node {
                parent.children.append(node)
            } else {
                roots.append(node)
            }
            ancestors.append((heading.level, node))
        }
        return roots.map { $0.value() }
    }

    private static func parseHeading(in originalLine: String, lineNumber: Int) -> Heading? {
        let line = removingComment(from: originalLine)
            .trimmingCharacters(in: .whitespaces)
        guard line.first == "\\" else { return nil }

        let commandStart = line.index(after: line.startIndex)
        var commandEnd = commandStart
        while commandEnd < line.endIndex, line[commandEnd].isLetter {
            commandEnd = line.index(after: commandEnd)
        }
        let command = String(line[commandStart..<commandEnd])
        guard let level = headingLevels[command] else { return nil }

        var cursor = commandEnd
        var isUnnumbered = false
        if cursor < line.endIndex, line[cursor] == "*" {
            isUnnumbered = true
            cursor = line.index(after: cursor)
        }
        skipWhitespace(in: line, cursor: &cursor)
        if cursor < line.endIndex, line[cursor] == "[" {
            guard let end = endOfBalancedGroup(in: line, from: cursor, open: "[", close: "]")
            else { return nil }
            cursor = line.index(after: end)
            skipWhitespace(in: line, cursor: &cursor)
        }
        guard cursor < line.endIndex, line[cursor] == "{",
            let titleEnd = endOfBalancedGroup(in: line, from: cursor, open: "{", close: "}")
        else { return nil }

        let titleStart = line.index(after: cursor)
        let title = displayTitle(String(line[titleStart..<titleEnd]))
        guard !title.isEmpty else { return nil }
        return Heading(
            title: title,
            command: command,
            level: level,
            line: lineNumber,
            isUnnumbered: isUnnumbered
        )
    }

    private static func removingComment(from line: String) -> String {
        for index in line.indices where line[index] == "%" {
            var slashCount = 0
            var cursor = index
            while cursor > line.startIndex {
                cursor = line.index(before: cursor)
                guard line[cursor] == "\\" else { break }
                slashCount += 1
            }
            if slashCount.isMultiple(of: 2) {
                return String(line[..<index])
            }
        }
        return line
    }

    private static func skipWhitespace(in text: String, cursor: inout String.Index) {
        while cursor < text.endIndex, text[cursor].isWhitespace {
            cursor = text.index(after: cursor)
        }
    }

    private static func endOfBalancedGroup(
        in text: String,
        from start: String.Index,
        open: Character,
        close: Character
    ) -> String.Index? {
        var depth = 0
        var cursor = start
        while cursor < text.endIndex {
            let character = text[cursor]
            if character == open {
                depth += 1
            } else if character == close {
                depth -= 1
                if depth == 0 { return cursor }
            }
            cursor = text.index(after: cursor)
        }
        return nil
    }

    private static func displayTitle(_ source: String) -> String {
        let withoutCommands = source.replacingOccurrences(
            of: #"\\[A-Za-z@]+\*?"#,
            with: "",
            options: .regularExpression
        )
        return
            withoutCommands
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
    }
}
