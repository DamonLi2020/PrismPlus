import Foundation

protocol LaTeXCompiling: Sendable {
    func compile(source: String) async throws -> CompilationResult
    func compile(source: String, projectDirectoryURL: URL?) async throws -> CompilationResult
}

extension LaTeXCompiling {
    func compile(source: String, projectDirectoryURL: URL?) async throws -> CompilationResult {
        try await compile(source: source)
    }
}

actor TectonicCompiler: LaTeXCompiling {
    private let executableURL: URL
    private let processRunner: any ProcessRunning

    init(
        executableURL: URL? = nil,
        processRunner: any ProcessRunning = FoundationProcessRunner()
    ) {
        self.executableURL = executableURL ?? TectonicExecutableLocator.locate()
        self.processRunner = processRunner
    }

    func compile(source: String) async throws -> CompilationResult {
        try await compile(source: source, projectDirectoryURL: nil)
    }

    func compile(
        source: String,
        projectDirectoryURL: URL?
    ) async throws -> CompilationResult {
        let workspaceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismPlusBuild-\(UUID().uuidString)", isDirectory: true)
        let outputDirectoryURL = workspaceURL.appendingPathComponent("build", isDirectory: true)
        let inputURL = workspaceURL.appendingPathComponent("main.tex")

        try FileManager.default.createDirectory(
            at: outputDirectoryURL,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: workspaceURL) }

        if let projectDirectoryURL {
            try stageProjectResources(
                from: projectDirectoryURL,
                into: workspaceURL,
                excludingNames: [inputURL.lastPathComponent, outputDirectoryURL.lastPathComponent]
            )
        }
        try source.write(to: inputURL, atomically: true, encoding: .utf8)

        let invocation = TectonicCommandBuilder.makeInvocation(
            executableURL: executableURL,
            inputURL: inputURL,
            outputDirectoryURL: outputDirectoryURL,
            currentDirectoryURL: workspaceURL
        )
        let processResult = try await processRunner.run(invocation)
        return CompilationArtifactLoader.load(
            from: outputDirectoryURL,
            sourceBaseName: "main",
            processResult: processResult
        )
    }

    private func stageProjectResources(
        from projectDirectoryURL: URL,
        into workspaceURL: URL,
        excludingNames: Set<String>
    ) throws {
        let resourceURLs = try FileManager.default.contentsOfDirectory(
            at: projectDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for resourceURL in resourceURLs
        where !excludingNames.contains(resourceURL.lastPathComponent) {
            let stagedURL = workspaceURL.appendingPathComponent(resourceURL.lastPathComponent)
            try FileManager.default.createSymbolicLink(
                at: stagedURL,
                withDestinationURL: resourceURL
            )
        }
    }
}
