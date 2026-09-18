import Combine
import Foundation
import PDFKit

/// Loads a PDF file and lets you step through it page by page.
public final class PDFReader: ObservableObject {
    public let document: PDFDocument
    @Published public private(set) var currentPageIndex: Int = 0

    /// Fails if the file at `url` cannot be opened as a PDF.
    public init?(url: URL) {
        guard let document = PDFDocument(url: url) else { return nil }
        self.document = document
    }

    /// Fails if `data` is not a valid PDF.
    public init?(data: Data) {
        guard let document = PDFDocument(data: data) else { return nil }
        self.document = document
    }

    public var pageCount: Int {
        document.pageCount
    }

    public var currentPage: PDFPage? {
        document.page(at: currentPageIndex)
    }

    public func page(at index: Int) -> PDFPage? {
        guard index >= 0, index < pageCount else { return nil }
        return document.page(at: index)
    }

    @discardableResult
    public func nextPage() -> PDFPage? {
        goToPage(currentPageIndex + 1)
    }

    @discardableResult
    public func previousPage() -> PDFPage? {
        goToPage(currentPageIndex - 1)
    }

    @discardableResult
    public func goToPage(_ index: Int) -> PDFPage? {
        guard index >= 0, index < pageCount else { return nil }
        currentPageIndex = index
        return currentPage
    }

    public var isAtLastPage: Bool {
        currentPageIndex >= pageCount - 1
    }

    public var isAtFirstPage: Bool {
        currentPageIndex <= 0
    }

    /// Plain text content of the page at `index`, if any.
    public func text(at index: Int) -> String? {
        page(at: index)?.string
    }
}
