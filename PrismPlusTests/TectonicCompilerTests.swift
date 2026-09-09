import Foundation
import Testing

@testable import PrismPlus

struct TectonicCompilerTests {
    @Test("Compiler writes source, invokes Tectonic safely, and returns generated PDF")
    func compilesInIsolatedWorkspace() async throws {
        let runner = SuccessfulProcessRunner()
        let compiler = TectonicCompiler(
            executableURL: URL(fileURLWithPath: "/test/tectonic"),
            processRunner: runner
        )
        let source = #"\documentclass{article}\begin{document}Hello\end{document}"#

        let result = try await compiler.compile(source: source)
        let capture = try #require(await runner.capture)

        #expect(result.succeeded)
        #expect(result.pdfData == Data("%PDF-generated".utf8))
        #expect(capture.source == source)
        #expect(capture.invocation.executableURL.path == "/test/tectonic")
        #expect(capture.invocation.arguments.contains("--untrusted"))
        #expect(capture.invocation.environment["TECTONIC_UNTRUSTED_MODE"] == "1")
    }
}

private actor SuccessfulProcessRunner: ProcessRunning {
    struct Capture: Sendable {
        let invocation: ProcessInvocation
        let source: String
    }

    private(set) var capture: Capture?

    func run(_ invocation: ProcessInvocation) async throws -> ProcessExecutionResult {
        let inputURL = URL(fileURLWithPath: try #require(invocation.arguments.last))
        let source = try String(contentsOf: inputURL, encoding: .utf8)
        capture = Capture(invocation: invocation, source: source)

        let outdirIndex = try #require(invocation.arguments.firstIndex(of: "--outdir"))
        let outputDirectoryURL = URL(
            fileURLWithPath: invocation.arguments[outdirIndex + 1],
            isDirectory: true
        )
        try Data("%PDF-generated".utf8)
            .write(to: outputDirectoryURL.appendingPathComponent("main.pdf"))

        return ProcessExecutionResult(
            exitCode: 0,
            standardOutput: "note: Writing main.pdf",
            standardError: ""
        )
    }
}
