import Testing

@testable import PrismPlus

struct LaTeXDiagnosticParserTests {
    @Test("Compiler output becomes ordered line-addressable diagnostics")
    func parsesErrorsAndWarnings() {
        let log = """
            main.tex:12: Undefined control sequence.
            LaTeX Warning: Label `eq:missing' multiply defined on input line 7.
            warning: a package emitted a general warning
            """

        let diagnostics = LaTeXDiagnosticParser.parse(log)

        #expect(diagnostics.count == 3)
        #expect(diagnostics[0].severity == .error)
        #expect(diagnostics[0].line == 12)
        #expect(diagnostics[0].message == "Undefined control sequence.")
        #expect(diagnostics[1].severity == .warning)
        #expect(diagnostics[1].line == 7)
        #expect(diagnostics[2].severity == .warning)
        #expect(diagnostics[2].line == nil)
    }

    @Test("Noise does not create false diagnostics")
    func ignoresNormalCompilerOutput() {
        let log = """
            note: Running TeX ...
            note: Writing `main.pdf`
            """

        #expect(LaTeXDiagnosticParser.parse(log).isEmpty)
    }
}
