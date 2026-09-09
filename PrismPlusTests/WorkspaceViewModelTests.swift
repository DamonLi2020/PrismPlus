import Foundation
import Testing

@testable import PrismPlus

@MainActor
struct WorkspaceViewModelTests {
    @Test("Incomplete completion input waits without invoking the compiler")
    func defersAutomaticCompilationForCompletionInput() async throws {
        let compiler = RecordingCompiler()
        let model = WorkspaceViewModel(compiler: compiler)

        model.updateSource(#"\s"#, deferAutomaticCompilation: true)

        #expect(model.buildState == .waiting)
        #expect(model.diagnostics.isEmpty)
        try await Task.sleep(for: .milliseconds(1_000))
        let compilationCount = await compiler.compilationCount
        #expect(compilationCount == 0)
    }
}

private actor RecordingCompiler: LaTeXCompiling {
    private(set) var compilationCount = 0

    func compile(source: String) async throws -> CompilationResult {
        compilationCount += 1
        return CompilationResult(succeeded: true, pdfData: nil, diagnostics: [], log: "")
    }
}
