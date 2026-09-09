import Foundation

protocol ProcessRunning: Sendable {
    func run(_ invocation: ProcessInvocation) async throws -> ProcessExecutionResult
}

enum ProcessRunnerError: LocalizedError {
    case timedOut(Duration)

    var errorDescription: String? {
        switch self {
        case .timedOut(let duration):
            "Tectonic did not finish within \(duration.formatted())."
        }
    }
}

struct FoundationProcessRunner: ProcessRunning {
    func run(_ invocation: ProcessInvocation) async throws -> ProcessExecutionResult {
        try await Task.detached(priority: .userInitiated) {
            try Self.runSynchronously(invocation)
        }.value
    }

    private static func runSynchronously(
        _ invocation: ProcessInvocation
    ) throws -> ProcessExecutionResult {
        let captureDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismPlusProcess-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: captureDirectoryURL,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: captureDirectoryURL) }

        let standardOutputURL = captureDirectoryURL.appendingPathComponent("stdout.txt")
        let standardErrorURL = captureDirectoryURL.appendingPathComponent("stderr.txt")
        FileManager.default.createFile(atPath: standardOutputURL.path, contents: nil)
        FileManager.default.createFile(atPath: standardErrorURL.path, contents: nil)

        let standardOutputHandle = try FileHandle(forWritingTo: standardOutputURL)
        let standardErrorHandle = try FileHandle(forWritingTo: standardErrorURL)
        defer {
            try? standardOutputHandle.close()
            try? standardErrorHandle.close()
        }

        let process = Process()
        process.executableURL = invocation.executableURL
        process.arguments = invocation.arguments
        process.currentDirectoryURL = invocation.currentDirectoryURL
        process.environment = ProcessInfo.processInfo.environment.merging(
            invocation.environment,
            uniquingKeysWith: { _, configured in configured }
        )
        process.standardOutput = standardOutputHandle
        process.standardError = standardErrorHandle

        try process.run()
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: invocation.timeout)

        while process.isRunning && clock.now < deadline {
            if Task.isCancelled {
                process.terminate()
                process.waitUntilExit()
                throw CancellationError()
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        guard !process.isRunning else {
            process.terminate()
            process.waitUntilExit()
            throw ProcessRunnerError.timedOut(invocation.timeout)
        }

        try standardOutputHandle.close()
        try standardErrorHandle.close()

        return ProcessExecutionResult(
            exitCode: process.terminationStatus,
            standardOutput: readUTF8(from: standardOutputURL),
            standardError: readUTF8(from: standardErrorURL)
        )
    }

    private static func readUTF8(from url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
}
