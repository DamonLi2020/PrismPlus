import PDFKit
import SwiftUI

struct PDFPreview: NSViewRepresentable {
    let data: Data

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.backgroundColor = .windowBackgroundColor
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        guard context.coordinator.displayedData != data else { return }
        let previousDocument = pdfView.document
        let previousPageIndex = previousDocument.flatMap { document in
            pdfView.currentPage.map { document.index(for: $0) }
        }
        let previousPoint = pdfView.currentDestination?.point
        let previousScale = pdfView.scaleFactor

        context.coordinator.displayedData = data
        guard let updatedDocument = PDFDocument(data: data) else { return }

        NSAnimationContext.runAnimationGroup { animationContext in
            animationContext.duration = 0
            pdfView.document = updatedDocument

            if let previousPageIndex,
                previousPageIndex >= 0,
                previousPageIndex < updatedDocument.pageCount,
                let page = updatedDocument.page(at: previousPageIndex)
            {
                pdfView.autoScales = false
                pdfView.scaleFactor = previousScale
                pdfView.go(
                    to: PDFDestination(
                        page: page,
                        at: previousPoint ?? page.bounds(for: pdfView.displayBox).origin
                    )
                )
            } else {
                pdfView.autoScales = true
            }
        }
    }

    final class Coordinator {
        var displayedData: Data?
    }
}
