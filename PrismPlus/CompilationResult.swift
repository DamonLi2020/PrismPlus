import Foundation

struct ProcessExecutionResult: Equatable, Sendable {
    let exitCode: Int32
    let standardOutput: String
    let standardError: String
}

struct CompilationResult: Equatable, Sendable {
    let succeeded: Bool
    let pdfData: Data?
    let diagnostics: [CompilationDiagnostic]
    let log: String
}

enum CompilationArtifactLoader {
    static func load(
        from outputDirectoryURL: URL,
        sourceBaseName: String,
        processResult: ProcessExecutionResult
    ) -> CompilationResult {
        let pdfURL = outputDirectoryURL.appendingPathComponent("\(sourceBaseName).pdf")
        let logURL = outputDirectoryURL.appendingPathComponent("\(sourceBaseName).log")
        let pdfData = try? Data(contentsOf: pdfURL)
        let tectonicLog = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
        let log = [processResult.standardOutput, processResult.standardError, tectonicLog]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        var diagnostics = LaTeXDiagnosticParser.parse(log)
        let succeeded = processResult.exitCode == 0 && pdfData != nil

        if !succeeded && diagnostics.isEmpty {
            let message = firstUsefulMessage(
                standardError: processResult.standardError,
                standardOutput: processResult.standardOutput,
                pdfWasProduced: pdfData != nil
            )
            diagnostics.append(CompilationDiagnostic(severity: .error, message: message))
        }

        return CompilationResult(
            succeeded: succeeded,
            pdfData: pdfData,
            diagnostics: diagnostics,
            log: log
        )
    }

    private static func firstUsefulMessage(
        standardError: String,
        standardOutput: String,
        pdfWasProduced: Bool
    ) -> String {
        for candidate in [standardError, standardOutput] {
            let message = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !message.isEmpty { return message }
        }

        return pdfWasProduced
            ? "Tectonic exited before compilation completed."
            : "Tectonic did not produce a PDF."
    }
}
