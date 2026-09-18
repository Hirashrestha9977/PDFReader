import PDFKit
import SwiftUI

extension PDFPage {
    /// Renders this page as a bitmap image at the given scale (2x by default, for retina sharpness).
    func rendered(scale: CGFloat = 2.0) -> PlatformImage {
        let size = bounds(for: .mediaBox).size
        return thumbnail(of: CGSize(width: size.width * scale, height: size.height * scale), for: .mediaBox)
    }
}

extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(UIKit)
        self.init(uiImage: platformImage)
        #elseif canImport(AppKit)
        self.init(nsImage: platformImage)
        #endif
    }
}

/// Shows a PDF one page at a time, with pinch-to-zoom and swipe-to-turn-page gestures.
public struct PDFPageReaderView: View {
    @ObservedObject private var reader: PDFReader

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    private let swipeThreshold: CGFloat = 60

    public init(reader: PDFReader) {
        self.reader = reader
    }

    public var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                Group {
                    if let page = reader.currentPage {
                        Image(platformImage: page.rendered())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                    } else {
                        Text("No page to display")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
                .gesture(SimultaneousGesture(magnificationGesture, dragGesture))
                .onTapGesture(count: 2) { toggleZoom() }
            }

            Divider()

            HStack {
                Button("Previous") { goToPreviousPage() }
                    .disabled(reader.isAtFirstPage)

                Spacer()

                Text("Page \(reader.currentPageIndex + 1) of \(reader.pageCount)")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Next") { goToNextPage() }
                    .disabled(reader.isAtLastPage)
            }
            .padding()
        }
        .onChange(of: reader.currentPageIndex) { _ in
            resetZoom()
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(maxScale, max(minScale, lastScale * value))
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= minScale {
                    resetZoom()
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > minScale else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { value in
                if scale > minScale {
                    lastOffset = offset
                    return
                }

                if value.translation.width < -swipeThreshold {
                    goToNextPage()
                } else if value.translation.width > swipeThreshold {
                    goToPreviousPage()
                }
            }
    }

    private func toggleZoom() {
        withAnimation {
            if scale > minScale {
                resetZoom()
            } else {
                scale = 2.0
                lastScale = 2.0
            }
        }
    }

    private func goToNextPage() {
        withAnimation { _ = reader.nextPage() }
    }

    private func goToPreviousPage() {
        withAnimation { _ = reader.previousPage() }
    }

    private func resetZoom() {
        withAnimation {
            scale = minScale
            lastScale = minScale
            offset = .zero
            lastOffset = .zero
        }
    }
}
