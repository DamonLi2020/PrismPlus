import Foundation
import Testing

@testable import PrismPlus

struct TectonicCompilerTests {
    @Test("Bundled Tectonic takes priority over machine-specific fallbacks")
    func prefersBundledCompiler() {
        let bundledURL = URL(
            fileURLWithPath: "/Applications/Prism Plus.app/Contents/MacOS/tectonic")
        let selectedURL = TectonicExecutableLocator.select(
            bundledExecutableURL: bundledURL,
            fallbackCandidates: [URL(fileURLWithPath: "/opt/homebrew/bin/tectonic")],
            fileExists: { _ in true }
        )

        #expect(selectedURL == bundledURL)
    }

    @Test("An installed Tectonic is used while developing outside an app bundle")
    func selectsFirstInstalledFallback() {
        let candidates = [
            URL(fileURLWithPath: "/opt/homebrew/bin/tectonic"),
            URL(fileURLWithPath: "/usr/local/bin/tectonic"),
        ]
        let selectedURL = TectonicExecutableLocator.select(
            bundledExecutableURL: nil,
            fallbackCandidates: candidates,
            fileExists: { $0 == candidates[1].path }
        )

        #expect(selectedURL == candidates[1])
    }

    @Test("A useful conventional path is retained when Tectonic is not installed")
    func retainsFallbackForActionableLaunchError() {
        let candidates = [
            URL(fileURLWithPath: "/opt/homebrew/bin/tectonic"),
            URL(fileURLWithPath: "/usr/local/bin/tectonic"),
        ]
        let selectedURL = TectonicExecutableLocator.select(
            bundledExecutableURL: nil,
            fallbackCandidates: candidates,
            fileExists: { _ in false }
        )

        #expect(selectedURL == candidates[0])
    }

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

    @Test("Project resources are staged beside the source visible to Tectonic")
    func makesProjectImagesVisibleToCompiler() async throws {
        let projectDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismPlusAssets-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: projectDirectory) }
        try FileManager.default.createDirectory(
            at: projectDirectory,
            withIntermediateDirectories: true
        )
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xD9])
        try imageData.write(to: projectDirectory.appendingPathComponent("frog.jpg"))

        let runner = SuccessfulProcessRunner()
        let compiler = TectonicCompiler(
            executableURL: URL(fileURLWithPath: "/test/tectonic"),
            processRunner: runner
        )

        _ = try await compiler.compile(
            source: #"\includegraphics{frog.jpg}"#,
            projectDirectoryURL: projectDirectory
        )

        let capture = try #require(await runner.capture)
        #expect(capture.siblingImageData == imageData)
        #expect(
            capture.invocation.currentDirectoryURL
                == URL(fileURLWithPath: capture.invocation.arguments.last!)
                .deletingLastPathComponent()
        )
    }
}

private actor SuccessfulProcessRunner: ProcessRunning {
    struct Capture: Sendable {
        let invocation: ProcessInvocation
        let source: String
        let siblingImageData: Data?
    }

    private(set) var capture: Capture?

    func run(_ invocation: ProcessInvocation) async throws -> ProcessExecutionResult {
        let inputURL = URL(fileURLWithPath: try #require(invocation.arguments.last))
        let source = try String(contentsOf: inputURL, encoding: .utf8)
        let siblingImageData = try? Data(
            contentsOf: inputURL.deletingLastPathComponent().appendingPathComponent("frog.jpg")
        )
        capture = Capture(
            invocation: invocation,
            source: source,
            siblingImageData: siblingImageData
        )

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
