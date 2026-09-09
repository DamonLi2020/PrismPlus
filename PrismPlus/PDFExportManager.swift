import Foundation

enum PDFExportManager {
    static func suggestedFilename(for sourceURL: URL?) -> String {
        guard let sourceURL else { return "Untitled.pdf" }
        return sourceURL.deletingPathExtension().lastPathComponent + ".pdf"
    }

    static func destinationBesideSource(for sourceURL: URL) -> URL {
        sourceURL.deletingPathExtension().appendingPathExtension("pdf")
    }

    static func write(_ data: Data, to destinationURL: URL) throws {
        try data.write(to: destinationURL, options: .atomic)
    }
}
