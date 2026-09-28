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
/// A "Read Aloud" switch at the top speaks each page and turns to the next one automatically.
public struct PDFPageReaderView: View {
    @ObservedObject private var reader: PDFReader
    @StateObject private var speaker = PDFPageSpeaker()

    @State private var isAutoReading = false

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
            HStack {
                Spacer()
                Toggle("Read Aloud", isOn: $isAutoReading)
                    .toggleStyle(SwitchToggleStyle())
                    .fixedSize()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

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
            if isAutoReading {
                readCurrentPage()
            }
        }
        .onChange(of: isAutoReading) { isOn in
            if isOn {
                readCurrentPage()
            } else {
                speaker.stop()
            }
        }
        .onDisappear {
            isAutoReading = false
            speaker.stop()
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

    /// Speaks the current page, then advances; pages without text are skipped. Turns itself off after the last page.
    private func readCurrentPage() {
        let text = reader.currentPage?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty {
            advanceAutoReading()
        } else {
            speaker.speak(text) { advanceAutoReading() }
        }
    }

    private func advanceAutoReading() {
        guard isAutoReading else { return }
        if reader.isAtLastPage {
            isAutoReading = false
        } else {
            goToNextPage()
        }
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
