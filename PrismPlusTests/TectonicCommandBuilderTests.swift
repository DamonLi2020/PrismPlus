import Foundation
import Testing

@testable import PrismPlus

struct TectonicCommandBuilderTests {
    @Test("Compilation commands enforce untrusted mode without a shell")
    func buildsSafeInvocation() {
        let executable = URL(fileURLWithPath: "/opt/homebrew/bin/tectonic")
        let input = URL(fileURLWithPath: "/tmp/work/main.tex")
        let output = URL(fileURLWithPath: "/tmp/work/build", isDirectory: true)

        let invocation = TectonicCommandBuilder.makeInvocation(
            executableURL: executable,
            inputURL: input,
            outputDirectoryURL: output
        )

        #expect(invocation.executableURL == executable)
        #expect(
            invocation.arguments == [
                "-X", "compile", "--untrusted", "--synctex", "--keep-logs", "--outdir",
                output.path, input.path,
            ]
        )
        #expect(invocation.environment["TECTONIC_UNTRUSTED_MODE"] == "1")
        #expect(invocation.timeout == .seconds(20))
    }
}
