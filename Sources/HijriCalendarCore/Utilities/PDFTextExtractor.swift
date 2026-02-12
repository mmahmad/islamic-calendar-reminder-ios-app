import Foundation
import PDFKit

struct PDFTextExtractor: TextExtracting {
    func extractText(from data: Data) -> String {
        guard let document = PDFDocument(data: data) else {
            return ""
        }

        var text = ""
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            if let pageText = page.string {
                text.append(pageText)
                text.append("\n")
            }
        }
        return text
    }
}
