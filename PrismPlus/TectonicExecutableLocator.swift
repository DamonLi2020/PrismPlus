import Foundation

enum TectonicExecutableLocator {
    private static let fallbackCandidates = [
        URL(fileURLWithPath: "/opt/homebrew/bin/tectonic"),
        URL(fileURLWithPath: "/usr/local/bin/tectonic"),
    ]

    static func locate(
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) -> URL {
        select(
            bundledExecutableURL: bundle.url(forAuxiliaryExecutable: "tectonic"),
            fallbackCandidates: fallbackCandidates,
            fileExists: fileManager.fileExists(atPath:)
        )
    }

    static func select(
        bundledExecutableURL: URL?,
        fallbackCandidates: [URL],
        fileExists: (String) -> Bool
    ) -> URL {
        if let bundledExecutableURL {
            return bundledExecutableURL
        }

        return fallbackCandidates.first(where: { fileExists($0.path) })
            ?? fallbackCandidates[0]
    }
}
