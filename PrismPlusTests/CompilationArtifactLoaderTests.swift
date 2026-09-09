import Foundation
import Testing

@testable import PrismPlus

struct CompilationArtifactLoaderTests {
    @Test("Successful compilation returns PDF bytes and parsed log diagnostics")
    func loadsSuccessfulArtifacts() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let expectedPDF = Data("%PDF-test".utf8)
        try expectedPDF.write(to: directory.appendingPathComponent("main.pdf"))
        try "LaTeX Warning: Reference undefined on input line 9."
            .write(
                to: directory.appendingPathComponent("main.log"),
                atomically: true,
                encoding: .utf8
            )

        let result = CompilationArtifactLoader.load(
            from: directory,
            sourceBaseName: "main",
            processResult: ProcessExecutionResult(
                exitCode: 0,
                standardOutput: "note: Writing main.pdf",
                standardError: ""
            )
        )

        #expect(result.succeeded)
        #expect(result.pdfData == expectedPDF)
        #expect(result.diagnostics.count == 1)
        #expect(result.diagnostics[0].line == 9)
        #expect(result.log.contains("Writing main.pdf"))
    }

    @Test("Failed compilation without a parsed error still produces a useful diagnostic")
    func reportsUnstructuredFailure() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = CompilationArtifactLoader.load(
            from: directory,
            sourceBaseName: "main",
            processResult: ProcessExecutionResult(
                exitCode: 1,
                standardOutput: "",
                standardError: "fatal: compilation stopped"
            )
        )

        #expect(!result.succeeded)
        #expect(result.pdfData == nil)
        #expect(result.diagnostics.count == 1)
        #expect(result.diagnostics[0].severity == .error)
        #expect(result.diagnostics[0].message == "fatal: compilation stopped")
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismPlusTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }
}
