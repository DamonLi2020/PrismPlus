import Foundation
import Testing

@testable import PrismPlus

struct PDFExportManagerTests {
    @Test("PDF export names follow the active LaTeX document")
    func derivesExportNameAndAdjacentDestination() {
        let sourceURL = URL(fileURLWithPath: "/tmp/paper.tex")

        #expect(PDFExportManager.suggestedFilename(for: sourceURL) == "paper.pdf")
        #expect(
            PDFExportManager.destinationBesideSource(for: sourceURL)
                == URL(fileURLWithPath: "/tmp/paper.pdf")
        )
        #expect(PDFExportManager.suggestedFilename(for: nil) == "Untitled.pdf")
    }

    @Test("PDF data is written atomically and may replace an older generated PDF")
    func writesPDFData() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismPlusPDFExport-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("paper.pdf")

        try PDFExportManager.write(Data("first".utf8), to: destination)
        try PDFExportManager.write(Data("updated".utf8), to: destination)

        #expect(try Data(contentsOf: destination) == Data("updated".utf8))
    }
}
