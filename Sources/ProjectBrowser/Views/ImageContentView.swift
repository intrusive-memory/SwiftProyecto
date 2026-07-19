import SwiftUI

public struct ImageContentView: View {
  private let file: ProjectFile
  private let directoryURL: URL

  @State private var scale: CGFloat = 1.0
  @State private var offset: CGSize = .zero
  @State private var loadingError: String?

  public init(file: ProjectFile, directoryURL: URL) {
    self.file = file
    self.directoryURL = directoryURL
  }

  public var body: some View {
    ZStack {
      Color(white: 0.95)
        .ignoresSafeArea()

      if let error = loadingError {
        VStack(spacing: 12) {
          Image(systemName: "photo.badge.exclamationmark.fill")
            .font(.system(size: 40))
            .foregroundStyle(.red)

          Text("Failed to load image")
            .font(.headline)

          Text(error)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding()
      } else {
        AsyncImage(url: fileURL) { phase in
          switch phase {
          case .empty:
            VStack(spacing: 12) {
              ProgressView()
                .controlSize(.large)
              Text("Loading image…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

          case .success(let image):
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
              image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .gesture(
                  SimultaneousGesture(
                    MagnificationGesture()
                      .onChanged { value in
                        scale = max(1.0, min(4.0, value))
                      },
                    DragGesture()
                      .onChanged { value in
                        offset = value.translation
                      }
                      .onEnded { _ in
                        withAnimation(.spring) {
                          offset = .zero
                        }
                      }
                  )
                )
            }

          case .failure(let error):
            VStack(spacing: 12) {
              Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.red)

              Text("Image load failed")
                .font(.headline)

              Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .padding()
            .onAppear {
              loadingError = error.localizedDescription
            }

          @unknown default:
            EmptyView()
          }
        }
      }
    }
    .navigationTitle(file.displayName)
  }

  private var fileURL: URL {
    directoryURL.appendingPathComponent(file.relativePath)
  }
}

#Preview("ImageContentView – Loading", traits: .fixedLayout(width: 480, height: 360)) {
  ImageContentView(
    file: ProjectFile(
      name: "poster.jpg",
      relativePath: "assets/poster.jpg",
      fileExtension: "jpg",
      isDirectory: false,
      modifiedDate: Date()
    ),
    directoryURL: FileManager.default.temporaryDirectory
  )
}

#Preview("ImageContentView – Error", traits: .fixedLayout(width: 480, height: 360)) {
  ImageContentView(
    file: ProjectFile(
      name: "missing.png",
      relativePath: "assets/missing.png",
      fileExtension: "png",
      isDirectory: false,
      modifiedDate: Date()
    ),
    directoryURL: FileManager.default.temporaryDirectory
  )
}
