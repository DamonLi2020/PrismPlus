import Foundation

enum LaTeXDiagnosticParser {
    private static let fileLinePattern = try! NSRegularExpression(
        pattern: #"^.+?:(\d+):\s*(.+)$"#
    )
    private static let inputLinePattern = try! NSRegularExpression(
        pattern: #"\bon input line\s+(\d+)\b"#,
        options: [.caseInsensitive]
    )

    static func parse(_ compilerOutput: String) -> [CompilationDiagnostic] {
        compilerOutput.split(whereSeparator: \.isNewline).compactMap(parseLine)
    }

    private static func parseLine(_ line: Substring) -> CompilationDiagnostic? {
        let text = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if let match = firstMatch(for: fileLinePattern, in: text),
            let lineNumber = integer(in: text, match: match, captureGroup: 1),
            let message = substring(in: text, match: match, captureGroup: 2)
        {
            return CompilationDiagnostic(
                severity: .error,
                message: message,
                line: lineNumber
            )
        }

        guard text.localizedCaseInsensitiveContains("warning:") else { return nil }

        let lineNumber = firstMatch(for: inputLinePattern, in: text)
            .flatMap { integer(in: text, match: $0, captureGroup: 1) }
        return CompilationDiagnostic(severity: .warning, message: text, line: lineNumber)
    }

    private static func firstMatch(
        for expression: NSRegularExpression,
        in text: String
    ) -> NSTextCheckingResult? {
        expression.firstMatch(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        )
    }

    private static func substring(
        in text: String,
        match: NSTextCheckingResult,
        captureGroup: Int
    ) -> String? {
        guard let range = Range(match.range(at: captureGroup), in: text) else { return nil }
        return String(text[range])
    }

    private static func integer(
        in text: String,
        match: NSTextCheckingResult,
        captureGroup: Int
    ) -> Int? {
        substring(in: text, match: match, captureGroup: captureGroup).flatMap(Int.init)
    }
}
