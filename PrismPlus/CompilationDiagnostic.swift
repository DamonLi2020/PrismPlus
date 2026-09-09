import Foundation

struct CompilationDiagnostic: Equatable, Identifiable, Sendable {
    enum Severity: String, Sendable {
        case error
        case warning
    }

    let id: UUID
    let severity: Severity
    let message: String
    let line: Int?

    init(
        id: UUID = UUID(),
        severity: Severity,
        message: String,
        line: Int? = nil
    ) {
        self.id = id
        self.severity = severity
        self.message = message
        self.line = line
    }
}
