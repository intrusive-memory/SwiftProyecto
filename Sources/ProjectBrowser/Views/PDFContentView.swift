import PDFKit
import SwiftUI

public struct PDFContentView: View {
  private let file: ProjectFile
  private let directoryURL: URL

  @State private var loadingError: String?

  public init(file: ProjectFile, directoryURL: URL) {
    self.file = file
    self.directoryURL = directoryURL
  }

  public var body: some View {
    ZStack {
      if let error = loadingError {
        VStack(spacing: 12) {
          Image(systemName: "doc.badge.exclamationmark")
            .font(.system(size: 40))
            .foregroundStyle(.red)

          Text("Failed to load PDF")
            .font(.headline)

          Text(error)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
      } else {
        PDFViewContainer(fileURL: fileURL, error: $loadingError)
      }
    }
    .navigationTitle(file.displayName)
  }

  private var fileURL: URL {
    directoryURL.appendingPathComponent(file.relativePath)
  }
}

#if os(iOS)
private struct PDFViewContainer: UIViewRepresentable {
  let fileURL: URL
  @Binding var error: String?

  func makeUIView(context: Context) -> PDFView {
    let pdfView = PDFView()
    pdfView.autoScales = true
    pdfView.displayDirection = .vertical
    pdfView.displayMode = .singlePageContinuous

    if let document = PDFDocument(url: fileURL) {
      pdfView.document = document
    } else {
      error = "Could not open PDF file"
    }

    return pdfView
  }

  func updateUIView(_ uiView: PDFView, context: Context) {}
}
#elseif os(macOS)
private struct PDFViewContainer: NSViewRepresentable {
  let fileURL: URL
  @Binding var error: String?

  func makeNSView(context: Context) -> PDFView {
    let pdfView = PDFView()
    pdfView.autoScales = true
    pdfView.displayDirection = .vertical
    pdfView.displayMode = .singlePageContinuous

    if let document = PDFDocument(url: fileURL) {
      pdfView.document = document
    } else {
      error = "Could not open PDF file"
    }

    return pdfView
  }

  func updateNSView(_ nsView: PDFView, context: Context) {}
}
#endif

#Preview("PDFContentView", traits: .fixedLayout(width: 480, height: 600)) {
  PDFContentView(
    file: ProjectFile(
      name: "document.pdf",
      relativePath: "docs/document.pdf",
      fileExtension: "pdf",
      isDirectory: false,
      modifiedDate: Date()
    ),
    directoryURL: FileManager.default.temporaryDirectory
  )
}
