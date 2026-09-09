import Foundation

struct ProcessInvocation: Equatable, Sendable {
    let executableURL: URL
    let arguments: [String]
    let environment: [String: String]
    let timeout: Duration
    let currentDirectoryURL: URL?
}

enum TectonicCommandBuilder {
    static func makeInvocation(
        executableURL: URL,
        inputURL: URL,
        outputDirectoryURL: URL,
        currentDirectoryURL: URL? = nil
    ) -> ProcessInvocation {
        ProcessInvocation(
            executableURL: executableURL,
            arguments: [
                "-X", "compile", "--untrusted", "--synctex", "--keep-logs", "--outdir",
                outputDirectoryURL.path, inputURL.path,
            ],
            environment: ["TECTONIC_UNTRUSTED_MODE": "1"],
            timeout: .seconds(20),
            currentDirectoryURL: currentDirectoryURL
        )
    }
}
